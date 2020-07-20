#include <iostream>
#include <memory>
#include <string>

#include "steam.grpc.pb.h"
#include <grpcpp/grpcpp.h>

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using steam::Steam;
using steam::SteamworksInitRequest;
using steam::SteamworksInitResult;
using steam::StateUpdateMessage;
using steam::StateUpdateAck;
using steam::DetailsUpdateMessage;
using steam::DetailsUpdateAck;

class SteamServiceImpl final : public Steam::Service {
    Status InitSteamworks(ServerContext* context, const SteamworksInitRequest* request, SteamworksInitResult* result){
        std::cout << "Received Initialization request." << std::endl;
        result->set_succeeded(true);
        result->set_user_name("Mike Lawson");
        return Status::OK;

    }
    Status UpdateGameState(ServerContext* context, const StateUpdateMessage* message, StateUpdateAck* result){
        std::cout << "Got a state update message: " << message->state() << std::endl;
        return Status::OK;
    }
    Status UpdateGameDetails(ServerContext* context, const DetailsUpdateMessage* message, DetailsUpdateAck* result){
        std::cout << "Got a details update message: " << message->details() << std::endl;
        return Status::OK;
    }
};

void runServer(){
    std::string server_address("0.0.0.0:50051");
    SteamServiceImpl service;
    ServerBuilder builder;
    
    // Listen on the given address without any authentication mechanism.
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    // Register "service" as the instance through which we'll communicate with
    // clients. In this case it corresponds to an *synchronous* service.
    builder.RegisterService(&service);
    // Finally assemble the server.
    std::unique_ptr<Server> server(builder.BuildAndStart());
    std::cout << "Server listening on " << server_address << std::endl;

    // Wait for the server to shutdown. Note that some other thread must be
    // responsible for shutting down the server for this call to ever return.
    server->Wait();
}

int main(int argc, char** argv){
    runServer();
    return 0;
}