FROM golang:1.25

WORKDIR /usr/src/app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

EXPOSE 50051

CMD ["go", "run", "."]
