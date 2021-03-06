FROM alpine/git as download
RUN mkdir /tmp/app
WORKDIR /tmp/app

# RUN git clone https://github.com/OHIF/Viewers.git --depth 1
# RUN git clone https://github.com/OHIF/Viewers.git --depth 1 -b refactor/1387 --single-branch
RUN git clone https://github.com/OsiriX-Foundation/Viewers.git --depth 1 -b projectweek --single-branch

FROM node:10.16.3-slim as builder

RUN mkdir /usr/src/app
WORKDIR /usr/src/app

# Copy Files
COPY --from=download /tmp/app/Viewers/.docker /usr/src/app/.docker
COPY --from=download /tmp/app/Viewers/.webpack /usr/src/app/.webpack
COPY --from=download /tmp/app/Viewers/extensions /usr/src/app/extensions
COPY --from=download /tmp/app/Viewers/platform /usr/src/app/platform
COPY --from=download /tmp/app/Viewers/.browserslistrc /usr/src/app/.browserslistrc
COPY --from=download /tmp/app/Viewers/aliases.config.js /usr/src/app/aliases.config.js
COPY --from=download /tmp/app/Viewers/babel.config.js /usr/src/app/babel.config.js
COPY --from=download /tmp/app/Viewers/lerna.json /usr/src/app/lerna.json
COPY --from=download /tmp/app/Viewers/package.json /usr/src/app/package.json
COPY --from=download /tmp/app/Viewers/postcss.config.js /usr/src/app/postcss.config.js
COPY --from=download /tmp/app/Viewers/yarn.lock /usr/src/app/yarn.lock

COPY default.js /usr/src/app/platform/viewer/public/config/default.js

# Run the install before copying the rest of the files
RUN yarn config set workspaces-experimental true
RUN yarn install

ENV PATH /usr/src/app/node_modules/.bin:$PATH
ENV QUICK_BUILD true
# ENV GENERATE_SOURCEMAP=false
# ENV REACT_APP_CONFIG=config/default.js

RUN yarn run build

# Stage 2: Bundle the built application into a Docker container
# which runs Nginx using Alpine Linux
FROM nginx:1.19.8-alpine
RUN apk add --no-cache bash
COPY default.conf /etc/nginx/templates/default.conf.template
COPY --from=builder /usr/src/app/.docker/Viewer-v2.x/entrypoint.sh /docker-entrypoint.d/1-ohif-entrypoint.sh
RUN chmod 777 /docker-entrypoint.d/1-ohif-entrypoint.sh
COPY --from=builder /usr/src/app/platform/viewer/dist /usr/share/nginx/html
EXPOSE 80
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
