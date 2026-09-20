package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"strings"
	"time"

	pb "google_stt_grpc/grpc/helloworld"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var port = flag.Int("port", 50051, "The server port")

// greeterServer implements helloworld.GreeterServer.
type greeterServer struct {
	pb.UnimplementedGreeterServer
}

func (s *greeterServer) SayHello(ctx context.Context, in *pb.HelloRequest) (*pb.HelloResponse, error) {
	log.Printf("Received SayHello: %v", in.GetName())
	return &pb.HelloResponse{Message: "Hello " + in.GetName()}, nil
}

func (s *greeterServer) SayHelloAgain(in *pb.HelloRequest, stream pb.Greeter_SayHelloAgainServer) error {
	log.Printf("Received SayHelloAgain: %v", in.GetName())
	for i := 0; i < 2; i++ {
		res := &pb.HelloResponse{Message: "Hello " + in.GetName()}
		if err := stream.Send(res); err != nil {
			return err
		}
		time.Sleep(1 * time.Second)
	}
	log.Printf("Closed SayHelloAgain")
	return nil
}

func (s *greeterServer) SayHelloToMany(stream pb.Greeter_SayHelloToManyServer) error {
	log.Printf("Open SayHelloToMany")
	var names []string
	for {
		in, err := stream.Recv()
		if err == io.EOF {
			log.Printf("Closed SayHelloToMany")
			return stream.SendAndClose(&pb.HelloResponse{
				Message: "Hello! " + strings.Join(names, ", "),
			})
		}
		if err != nil {
			return err
		}
		log.Printf("Received SayHelloToMany: %v", in.GetName())
		names = append(names, in.GetName())
	}
}

func (s *greeterServer) SayChat(stream pb.Greeter_SayChatServer) error {
	log.Printf("Open SayChat")
	for {
		in, err := stream.Recv()
		if err == io.EOF {
			log.Printf("Closed SayChat")
			return nil
		}
		if err != nil {
			return err
		}
		log.Printf("Received SayChat: %v", in.GetName())
		if err := stream.Send(&pb.HelloResponse{Message: "Hello " + in.GetName()}); err != nil {
			return err
		}
	}
}

func main() {
	flag.Parse()
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", *port))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()
	pb.RegisterGreeterServer(s, &greeterServer{})
	reflection.Register(s)

	log.Printf("server listening at %v", lis.Addr())
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
