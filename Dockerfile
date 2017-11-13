FROM golang

COPY ./src/ /app/

RUN go build -o /app/app /app/app.go

RUN chmod u+x /app/app

RUN chmod u+x /app/script/restart-container.sh

EXPOSE 80

CMD ["/app/app"]
