FROM node:23.5.0 AS build-stage
WORKDIR /src
COPY package.json .
COPY package-lock.json .
RUN ["npm", "ci"]
COPY . .
RUN ["npm", "run", "build"]

FROM httpd:2.4.62 AS serve-stage
COPY --from=build-stage /src/_site /usr/local/apache2/htdocs/
