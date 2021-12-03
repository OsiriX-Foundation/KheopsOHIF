FROM alpine/git as download
RUN mkdir /tmp/app
WORKDIR /tmp/app

# RUN git clone https://github.com/OHIF/Viewers.git --depth 1
RUN git clone https://github.com/OsiriX-Foundation/Viewers.git --depth 1 -b v3-stable --single-branch

# Stage 1: Build the application
# docker build -t ohif/viewer:latest .
FROM node:14.3.0-slim as json-copier

RUN mkdir /usr/src/app
WORKDIR /usr/src/app

# Copy Files
COPY --from=download /tmp/app/Viewers/package.json /usr/src/app/package.json
COPY --from=download /tmp/app/Viewers/yarn.lock /usr/src/app/yarn.lock

#TODO COPY ./

COPY --from=download /tmp/app/Viewers/extensions /usr/src/app/extensions
COPY --from=download /tmp/app/Viewers/modes /usr/src/app/modes
COPY --from=download /tmp/app/Viewers/platform /usr/src/app/platform

# Find and remove non-package.json files
RUN find extensions \! -name "package.json" -mindepth 2 -maxdepth 2 -print | xargs rm -rf
RUN find modes \! -name "package.json" -mindepth 2 -maxdepth 2 -print | xargs rm -rf
RUN find platform \! -name "package.json" -mindepth 2 -maxdepth 2 -print | xargs rm -rf

#TODO : still needed?
COPY default.js /usr/src/app/platform/viewer/public/config/default.js

# Find and remove non-package.json files
RUN find extensions \! -name "package.json" -mindepth 2 -maxdepth 2 -print | xargs rm -rf
RUN find modes \! -name "package.json" -mindepth 2 -maxdepth 2 -print | xargs rm -rf
RUN find platform \! -name "package.json" -mindepth 2 -maxdepth 2 -print | xargs rm -rf

# Copy Files
FROM node:14.3.0-slim as builder
RUN mkdir /usr/src/app
WORKDIR /usr/src/app

COPY --from=json-copier /usr/src/app .

# Run the install before copying the rest of the files
RUN yarn config set workspaces-experimental true
RUN yarn install --frozen-lockfile --verbose

COPY --from=download /tmp/app/Viewers/ .

# To restore workspaces symlinks
RUN yarn install --frozen-lockfile --verbose

ENV PATH /usr/src/app/node_modules/.bin:$PATH
ENV QUICK_BUILD true

RUN yarn run build --verbose

# Stage 2: Bundle the built application into a Docker container
# which runs Nginx using Alpine Linux
FROM nginx:1.21.1-alpine
RUN apk add --no-cache bash
RUN rm -rf /etc/nginx/conf.d

COPY default.conf /etc/nginx/templates/default.conf.template

COPY --from=builder /usr/src/app/.docker/Viewer-v2.x /etc/nginx/conf.d
COPY --from=builder /usr/src/app/.docker/Viewer-v2.x/entrypoint.sh /usr/src/

RUN chmod 777 /usr/src/entrypoint.sh
COPY --from=builder /usr/src/app/platform/viewer/dist /usr/share/nginx/html

EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/usr/src/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
