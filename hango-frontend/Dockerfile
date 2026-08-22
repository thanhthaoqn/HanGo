FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /workspace/hango-frontend

COPY hango-frontend/pubspec.yaml hango-frontend/pubspec.lock ./
COPY doc/templates /workspace/doc/templates
RUN flutter pub get

COPY hango-frontend/lib ./lib
COPY hango-frontend/assets ./assets
COPY hango-frontend/web ./web
RUN flutter build web --release

FROM nginx:alpine AS runtime

COPY --from=build /workspace/hango-frontend/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
