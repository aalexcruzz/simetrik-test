import grpc
import logging
import os 
import helloworld_pb2_grpc as pb2_grpc
import helloworld_pb2 as pb2

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class HelloworldClient:
    """
    Client for gRPC functionality
    """

    def __init__(self):
        self.host = self._get_env_var('GRPC_SERVER_HOST')
        self.server_port = int(self._get_env_var('GRPC_SERVER_PORT'))
        
        logging.info(f"Initializing gRPC client to connect to {self.host}:{self.server_port}")
        self.channel = grpc.insecure_channel(f'{self.host}:{self.server_port}')
        self.stub = pb2_grpc.helloworldStub(self.channel)

    def _get_env_var(self, var_name):
        """Get environment variable or raise detailed error"""
        value = os.environ.get(var_name)
        if not value:
            raise ValueError(
                f"Missing required environment variable: {var_name}. "
                "Check Kubernetes deployment configuration."
            )
        return value

    def get_url(self, message):     
        logging.info(f"Sending message to server: {message}")
        try:
            message = pb2.Message(message=message)
            response = self.stub.GetServerResponse(message)
            logging.info(f"Received response from server: {response}")
            return response
        except Exception as e:
            logging.error(f"Error while communicating with gRPC server: {e}", exc_info=True)
            return None


if __name__ == '__main__':
    client = HelloworldClient()
    result = client.get_url(message="Hello to gRPC server from client")
    if result:
        print(f'{result}')
    else:
        print("Failed to receive response from server.")