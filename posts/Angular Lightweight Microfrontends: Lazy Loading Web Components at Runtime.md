---
title: "Angular Lightweight Microfrontends: Lazy Loading Web Components at Runtime"
description: Lazy loading of Angular components during runtime execution
date: 2026-11-26
tags:
  - Angular
  - microfrontend
  - architecture
layout: layouts/post.njk
---

Imagine the following scenario: multiple teams working on various Angular applications, and every app requires one component with the same behavior. Instead of copy-pasting the component in every project, you can keep it in a single repository, build it once as a [Web Component](https://developer.mozilla.org/en-US/docs/Web/API/Web_components) and serve it behind some HTTP server like NGINX. Whichever app needs it, it can pull it from that server, lazily load it and show it in the UI. 

Above can be accomplished with the following two libraries:

1. [@angular/elements](https://angular.dev/guide/elements) - for building the reusable component
2. [@angular-extensions/elements](https://github.com/angular-extensions/elements) - for lazy loading the built component

The idea will be showcased with a simple QR code generator app. It will consist of 3 parts:

1. The reusable component will accept an arbitrary text as input, based on it generate QR code and render it
2. NGINX Docker container will serve the *main.js* file built from the reusable component
3. Host application will lazily load the *main.js* and render the component only when user wants it. It will also expose textbox for entering the text upon which QR code will be generated

Source code of the entire project and corresponding *README* files can be located [here](https://github.com/ElvaRivle/Angular-Lightweight-Component-Based-Microfrontend-Blog).

> **NOTE**
> 
> ❗️ Reason for the word *Lightweight* in the title is because this is not a full-fledged microfrontend architecture showcase, but more widget/component-level microfrontend pattern, suitable for smaller components

# Building and Hosting the Reusable Component

Most important details are the following:

- Generate a new Angular application
- Install *@angular/elements* and *angularx-qrcode* NPM packages
- We need build output to produce *main.js* file without random characters in filename added by Angular for [cache busting](https://www.keycdn.com/support/what-is-cache-busting). This is done by disabling [output hashing](https://angular.dev/cli/build) in *angular.json*
- *main.ts* requires the most attention, so an explanation for it is below

Once the implementation is completed, run `npm run build`. This will build the application and place the resulting files in *dist/qr-display* folder. 

## main.ts

By default, *main.ts* uses `bootstrapApplication`. This method requires a root component that will be mounted to DOM. Since our reusable component app has no DOM on its own, but it will utilize host app's DOM, we don't need such a thing. Instead, we just need to register the component and somebody else (host app) will render it. Method we will use instead is `createApplication`.

More info on registry of custom elements in browser can be found [here](https://developer.mozilla.org/en-US/docs/Web/API/Window/customElements).

## Serving *main.js*

Create a new folder outside the Angular project, which will be used for serving the *main.js* via NGINX. Inside of it create *app* folder alongside the following *docker-compose.yaml* file:

```yaml
services:
  nginx:
    image: nginx:alpine
    container_name: nginx-web
    ports:
      - "8080:80"
    volumes:
      - ./app:/usr/share/nginx/html:ro
    restart: unless-stopped
```

Copy entire *qr-display* from *dist* (not the *dist* itself) into *app* folder and run `docker compose up -d`. Verify that you can access *main.js* file by visiting http://localhost:8080/qr-display/main.js.


# Host Application

Most important details are the following:

- Generate a new Angular application
- Install *@angular-extensions/elements* NPM package
- In the host app's component import `LazyElementDirective` and add `schemas` array with `CUSTOM_ELEMENTS_SCHEMA`
    - `LazyElementsDirective`'s responsibility is to download the *main.js* file, but only when absolutely necessary, adds `beforeLoad` and `afterLoad` lifecycle hooks to the reusable component and allows property binding and event listeners
    - `CUSTOM_ELEMENTS_SCHEMA` makes Angular not complain in case it comes across an unknown component, which our reusable component initially is, before it gets loaded and registered. But this also relaxes template validation, so use this only when strictly necessary
- Configure proxy, more info below
- Load and render the component inside HTML, more info below

Run `npm run start` and play around. 

## Proxy Configuration

The *main.js* is accessible via http://localhost:8080/qr-display/main.js. So we need to tell the Angular app running in the browser to do the following:

> Whenever you try to access http://localhost:4200/qr-display/main.js, actually go to http://localhost:8080/qr-display/main.js 

In the root of the project create `proxy.conf.js` file and add the following content:

```js
const PROXY_CONF = [
    {
        context: ['/qr-display'],
        target: 'http://localhost:8080'
    }
]

module.exports = PROXY_CONF
```

Under *serve* architect in *angular.json*, make Angular actually read this file and configure proxies:

```json
"options": {
    "proxyConfig": "proxy.conf.js"
},
```

## Loading and Rendering the Reusable Component

HTML in the host application will contain the following block of code:

```
<qr-display
    *axLazyElement="'/qr-display/main.js'; module: true"
    [attr.url]="url()"
>
</qr-display>
```

**Very important detail** is that the HTML tag **must** match the tag defined in `customElements.define` method call inside reusable component's *main.ts* file, which in our case is `qr-display`.

Angular's default builder *@angular/build:application* builds the application as an ESM, more info [here](https://angular.dev/tools/cli/build-system-migration). Because of that, we should set `module` to true. 

One last important detail is about passing input to the reusable component. You must prefix all inputs with `attr.` and convert all camelCases to kebab-cases. So input signal with the name of `someInputSignal` will be passed as `attr.some-input-signal`. Naming of output signals is not affected, they should remain as is. 

# Loading and Error Templates

Lazy loading in a way shown above also allows us to write `ng-template` elements in case where component loading fails, or display something (spinner for example) while the component is loading. Both of these are supported out of the box. This can be achieved with the following structure:

```
<ng-template #loading>Spinner</ng-template>
<ng-template #error>Error</ng-template>
<custom-component *axLazyElement="...; loadingTemplate: loading; errorTemplate: error;"></custom-component>
```

# How This Might Look Like in Prod Environment

Once built, *main.js* could be served behind NGINX from a pod in Kubernetes running under a certain namespace. SPA in another namespace could access it, but communication needs to be setup properly (*HTTPRoute* with *ReferenceGrant* for example). *proxy.conf.js* that we mentioned earlier is only for local development. 

So in a nutshell, it boils down to a single HTTP call, which should be fairly trivial in any architecture (ignoring caching, authN, authZ, CDN...). 

# What About Versioning and Contract-Breaking Changes?

This is a very important topic to discuss, and it completely depends on the scope of component's usage.

If the component is used internally at a company, either within a single team or group of teams, semantic versioning might be an overkill. Publish JS files under major version only (e.g. */qr-display/1/main.js*), override the version for simple bug fixes and improvements and reserve major version bump only for contract-changing (input and output signals), or when behavior changes significantly. 

On the other hand, if the component will be used by a wider audience, semantic versioning might make more sense:
- **major** - contract braking changes and potentially non-backward changes in behavior
- **minor** - new backwards-compatible behavior
- **patch** - backwards-compatible bug fixes

Regardless of the strategy, always remember: **contract changes require new major version**. 


# Drawbacks and Other Potential Solutions

The biggest drawbacks of this approach are the following:

1. The generated bundle can include Angular runtime dependencies, so the result is one or more additional Angular runtimes at the same time. Due to this, if running older *zone.js* based Angular apps, it's important to disable *zone.js* from reusable component's polyfill, since no multiple zones can co-exist
2. Input and output binding is not trivial, due to mixture of kebab and camel cases, timing, complex types and losing the type of the output from component (it gets converted to native `CustomEvent`)
3. CSS leakage could occur and styles could end up not applying properly
4. If `outputHashing` is disabled, browser could potentially keep the stale *main.js* file, if cache is not set up properly

Potential other solutions to this approach are:

- Building custom Web Elements with another, more lightweight tool, such as [Lit](https://lit.dev/) or [Stencil](https://stenciljs.com/docs/introduction)
- Federation, which allows sharing dependencies and smaller memory footprint, but increases the project setup complexity
