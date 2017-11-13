FROM golang

COPY ./src/ /app/

RUN go build -o /app/app /app/app.go

RUN chmod u+x /app/app

EXPOSE 80

CMD ["/app/app"]
