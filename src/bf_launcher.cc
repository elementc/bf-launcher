#include <iostream>
#include <memory>
#include <string>

#include "steam.grpc.pb.h"
#include <grpcpp/grpcpp.h>

#include <process.hpp>
#include <thread>
#include <mutex>
#include <chrono>

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
using namespace std::chrono_literals;

// Blocks launching bitfighter until the grpc server is finished starting up.
std::mutex grpc_init_gate;
bool grpc_is_started= false;

// Implementation of the Steamworks protocol.
class SteamServiceImpl final : public Steam::Service {
    public: 
        Status InitSteamworks(ServerContext* context, const SteamworksInitRequest* request, SteamworksInitResult* result){
            std::cout << "Received Initialization request." << std::endl;
            if (!is_init){
                is_init = true;
                result->set_succeeded(true);
                result->set_user_name("Mike Lawson");
                std::cout << "Steam login complete." << std::endl;
                return Status::OK;
            } else {
                std::cerr << "Steam is already logged in! Not re-initing." << std::endl;
                return Status::CANCELLED;
            }

        }
        Status UpdateGameState(ServerContext* context, const StateUpdateMessage* message, StateUpdateAck* result){
            std::cout << "Got a state update message: " << message->state() << std::endl;
            return Status::OK;
        }
        Status UpdateGameDetails(ServerContext* context, const DetailsUpdateMessage* message, DetailsUpdateAck* result){
            std::cout << "Got a details update message: " << message->details() << std::endl;
            return Status::OK;
        }
    private:
        bool is_init = false;
    };

// Thread entry point for the gRPC server.
void runServer(){

    grpc_init_gate.lock();
    
    std::string server_address("localhost:50051");
    SteamServiceImpl service;

    ServerBuilder builder;
    
    // Listen on the given address without any authentication mechanism.
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());

    // Register "service" as the instance through which we'll communicate with
    // clients. In this case it corresponds to an *synchronous* service.
    builder.RegisterService(&service);

    // Finally, assemble the server.
    std::unique_ptr<Server> server(builder.BuildAndStart());
    std::cout << "Server listening on " << server_address << std::endl;

    grpc_is_started = true;
    grpc_init_gate.unlock();

    // Wait for the server to shutdown. Note that some other thread must be
    // responsible for shutting down the server for this call to ever return.
    server->Wait();
}

// Thread entry point for the Bitfighter process.
void start_proc(const std::string proc){

    // Block until gRPC is finished starting up.
    while(true){
        grpc_init_gate.lock();
        if (grpc_is_started){
            break;
        }
        grpc_init_gate.unlock();
        std::this_thread::sleep_for(1ms);
    }

    // Launch bitfighter.
    TinyProcessLib::Process bf_process(proc, "", [](const char* bytes, size_t n) {
    std::cout << "Output from stdout: " << std::string(bytes, n) << std::endl;
    });

    // Block until bitfighter terminates.
    auto exit_status = bf_process.get_exit_status();
}

// Application entry point.
int main(int argc, char** argv) {

    // Make sure args are sane.
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " /path/to/a/bitfighter/executable" << std::endl;
        return -1;
    }


    // The two threads we manage.
    std::thread grpc_server(runServer);
    std::thread proc_runner(start_proc, std::string(argv[1]));

    // Wait for Bitfighter to quit.
    proc_runner.join();

    // Then let go of the gRPC server thread so we can shut down cleanly.
    grpc_server.detach();

    return 0;
}