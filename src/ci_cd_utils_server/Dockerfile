FROM dart:2.19.3 AS build
WORKDIR /app/
COPY . .
RUN dart pub get
RUN dart compile exe lib/main.dart -o server
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/
EXPOSE 4678
CMD ["/app/server", "serve"]