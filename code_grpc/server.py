import grpc
from concurrent import futures
import example_pb2
import example_pb2_grpc

class ExampleService(example_pb2_grpc.ExampleServiceServicer):
    def SendMessage(self, request, context):
        return example_pb2.ResponseMessage(message=f"Received: {request.message}")

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    example_pb2_grpc.add_ExampleServiceServicer_to_server(ExampleService(), server)
    server.add_insecure_port('[::]:50051')
    server.start()
    server.wait_for_termination()

if __name__ == '__main__':
    serve()
