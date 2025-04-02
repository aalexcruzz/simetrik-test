import grpc
import example_pb2
import example_pb2_grpc

def run():
    server_host = "grpc-server"
    with grpc.insecure_channel(f"{server_host}:80") as channel:
        stub = example_pb2_grpc.ExampleServiceStub(channel)
        response = stub.SendMessage(example_pb2.RequestMessage(message="Hello Server"))
        print(f"Server Response: {response.message}")

if __name__ == '__main__':
    run()


File create 