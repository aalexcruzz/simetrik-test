import grpc
from concurrent import futures
import logging
import re
import helloworld_pb2_grpc as pb2_grpc
import helloworld_pb2 as pb2
from grpc_reflection.v1alpha import reflection

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class helloworldService(pb2_grpc.helloworldServicer):

    def __init__(self, *args, **kwargs):
        pass

    def GetServerResponse(self, request, context):
        peer = context.peer()
        match = re.match(r"^ipv[46]:(?:\[?([^]]*)\]?):(\d+)$", peer)
        if match:
            client_ip = match.group(1)
            client_port = match.group(2)
        else:
            client_ip, client_port = 'unknown', 'unknown'
            
        logging.info(f"Received message '{request.message}' from {client_ip}:{client_port}")
        result = {
            'message': f'Thanks for your message! Server received: {request.message}',
            'received': True
        }
        return pb2.MessageResponse(**result)

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    pb2_grpc.add_helloworldServicer_to_server(helloworldService(), server)
    SERVICE_NAMES = (
        pb2.DESCRIPTOR.services_by_name['helloworld'].full_name,
        reflection.SERVICE_NAME,
    )
    reflection.enable_server_reflection(SERVICE_NAMES, server)
    server.add_insecure_port('[::]:9000')
    
    logging.info("Starting gRPC server on port 9000...")
    server.start()
    server.wait_for_termination()

if __name__ == '__main__':
    serve()