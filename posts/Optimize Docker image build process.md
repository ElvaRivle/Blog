---
title: Optimize Docker image build process
description: Steps to optimize lengthy Docker image build process and the final image size
date: 2025-03-16
tags:
  - docker
  - docker image
layout: layouts/post.njk
---

When I first learned Docker and started using it in my projects, the majority of images I've built were gigabytes in size and took ages to build. That didn't pose any issues in the beginning, where projects weren't deployed anywhere. When I started pulling images in remote environments, saving disk space, network bandwidth and time spent pulling those images became significant topics that needed to be tackled. The main objective of this blog post is to shed light on the main techniques used to conquer those exact issues, iteratively, one technique at a time.

# Initial Dockerfile version

The project in which the techniques will be showcased is a small-sized React project, written some time ago in Node v20 and React v18. `Dockerfile` is placed in the root directory of the project. Here's it's initial version:

```Dockerfile
FROM node:20

WORKDIR /app
COPY . .
RUN yarn
RUN yarn build
RUN yarn global add serve

CMD serve -s build -p 80
```

The main points we can take from this `Dockerfile` are following:
1. base image is `node:20`
1. all work is done in the `/app` directory
1. all files from the project are copied over
1. dependencies are installed
1. production-ready static files are built
1. `serve` package is installed to serve the static files (something like Apache or NGINX would be more suitable in production environments)
1. static files from `build` directory are served on port 80

---

The first improvement will focus on the second point from the list, `"all files from the project are copied over"`. Currently, on every image build, the entire `node_modules` directory gets unnecessarily copied with the `COPY . .` command. Why don't we ignore the `node_modules` directory, and possibly some other files/directories that are necessary only for the local development machine (such as local `.env` file or similar)? By doing this, we will significantly reduce the size of the Docker image and reduce the stress on the storage medium. 

In the root of the project, in the same place `Dockerfile` is placed, create a `.dockerignore` file with the following content:

```text
node_modules
.env
(other files and directories, separated by newline)
```

---

We still haven't touched the `Dockerfile` itself. Let's discuss the next issue where we will actually need to modify the file itself.

During the image build process, Docker caches the result of every step from the `Dockerfile` into, so-called, [image layers](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/). Those layers can later be re-used when the image needs re-building due to new changes to the codebase. Unfortunately, the nature of the current `Dockerfile` prevents anything to be re-used from the Docker's cache to speed up the process (apart from the base image, `node:20`). 

To explain this better, let's imagine that we change something in the codebase and we don't touch `package.json` file. Even though we didn't touch it, the dependencies still get re-installed on the next image build, because Docker isn't smart enough to know that dependencies weren't changed, only application code. We need to somehow tell Docker to cache the installation of dependencies and reuse that cached image layer in every subsequent image build. 

# Second Dockerfile version

The fix for the above mentioned problem is found in the following `Dockerfile`:

```Dockerfile
FROM node:20

WORKDIR /app
COPY ./package.json ./
RUN yarn

COPY . .

RUN yarn build
RUN yarn global add serve

CMD serve -s build -p 80
```

The main aspects where this `Dockerfile` differs from the above one are:
1. initially, only `package.json` is copied over, and not the entire project
1. dependencies are installed
1. only then are the rest of the files copied over

Now, if we don't touch `package.json`, the caches made from `COPY ./package.json ./` and `RUN yarn` will get re-used in every subsequent image build process by Docker, basically skipping the entire process of dependencies installation. 

```text
=> CACHED [3/7] COPY ./package.json ./ 0.0s
=> CACHED [4/7] RUN yarn
```

> **NOTE**
> 
> ❗️ This is not true only for NodeJS based projects. We need to think about the order of execution for other languages and tools as well, in order to fully utilize Docker caching capabilities. 


---

Let's discuss the above `Dockerfile`, since there's still plenty of room for improvement. Remember that each command in `Dockerfile` creates a new image layer. Image layers require disk space to be stored and also take time to be created and cached. So let's minimize the number of layers by combining multiple commands into one wherever possible.

# Third Dockerfile version

The fix for the above mentioned problem is found in the following `Dockerfile`:

```Dockerfile
FROM node:20

WORKDIR /app
COPY ./package.json ./
RUN yarn

COPY . .

RUN yarn build && yarn global add serve

CMD serve -s build -p 80
```

The only aspect where this `Dockerfile` differs from the above one is that the two final `RUN` commands are merged into one. So building static files and adding `serve` package is done in a single image layer, and not two.

Sure, we have combined only two commands into one, but imagine `Dockerfile` with dozens, or even hundreds of lines of code. The amount of improvement would be more significant. 

---

Now let's take a look at the base image, `node:20`. It's size is about 370 MB. Do we have a possibility to reduce this size?

# Fourth Dockerfile version

We have two possibilities, either create a custom minimalistic base image, or use the one that Node developers provided themselves. First option can quickly become very complex, so let's see how the second option looks like:

```Dockerfile
FROM node:20-alpine

WORKDIR /app
COPY ./package.json ./
RUN yarn

COPY . .

RUN yarn build && yarn global add serve

CMD serve -s build -p 80
```

The only aspect where this `Dockerfile` differs from the above one is that the base image is now `node:20-alpine`, instead of `node:20`. `node:20-alpine` is measly 45 MB in size, compared to 370 MB of regular `node:20` image. You can read more about the Alpine Linux project [here](https://alpinelinux.org/about/). 

> **NOTE**
> 
> ❗️ Since Alpine Linux image is very minimalistic, your applications may not work with this image as the base due to missing dependencies. In the case where Alpine doesn't work for you, you can build your own minimalistic base image by exploring topics such as `scratch` image, distroless, `busybox`, `Debian` base image...

---

We'll discuss just one more optimization technique, and probably one of the most powerful one. When we look at the `Dockerfile` above, the question comes to mind, can we somehow make the final Docker image contain only the data and tools necessary to actually run the app and remove everything else that isn't necessary? We don't need `node_modules`, we don't need possible build artifacts and caches left by Node, we don't need the actual raw React code anymore, but all of that is left in the final image...  

# Fifth Dockerfile version

Method for splitting the image building process is called [multi-stage builds](https://docs.docker.com/build/building/multi-stage/). In this case, we will split it into two: generating static files (`build-stage`), and actually serving those static files (`deployment-stage`). This is how the final `Dockerfile` looks like:

```Dockerfile
FROM node:20-alpine AS build-stage

WORKDIR /app
COPY . .
RUN yarn && yarn build

###

FROM node:20-alpine AS deployment-stage

RUN yarn global add serve
COPY --from=build-stage /app/build static_files

CMD serve -s static_files -p 80

```

What we have gained from this multi-stage builds? In the final image, there exists no `node_modules` directory, no build artifacts, no React code, so the final image size will be drastically smaller. All of that "build residue" is left behind in the `build-stage` stage and nothing from that stage has leaked into the `deployment-stage`. We can pick and choose files and folder that will end up in the final stage via `COPY --from=<stage-name>`.

# Conclusion

Number don't lie, let's take a look at build times and final image sizes (image builds performed on an old but trusty dual core ThinkPad T450):

- Initial version (least optimized solution)
  - 385 seconds
  - 2.33 GB
- Initial version (with `.dockerignore`)
  - 308 seconds
  - 1.96 GB
- Second version (smarter order of execution)
  - Before code change
    - 353 seconds
    - 1.96 GB
  - After code change
    - 224 seconds
    - 1.96 GB
- Third version (merging same consecutive commands into one)
  - 225 seconds
  - 1.95 GB
- Fourth version (smaller base image)
  - 
  - 
- Fifth version (multi-stage build)
  - 
  - 

We can clearly see that some techniques improve speed of build process, while others reduce the final image size. They are all small changes to the `Dockerfile` by themselves, but cumulated, they result in significant improvements. In the end, the speed of image building process was reduced by X%, while the size of the final image dropped by whooping X%.  This is a very powerful showcase of how small changes can sometimes cause significant positive impact on a large scheme of things. 
