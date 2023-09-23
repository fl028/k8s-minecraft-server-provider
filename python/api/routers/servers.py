from fastapi import APIRouter, HTTPException, Path
from pydantic import BaseModel
from kubernetes import client, config
from kubernetes.stream import stream

router = APIRouter(prefix="/server",tags=["server"])
config.load_incluster_config()

class Server(BaseModel):
    servername: str
    port: int

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "servername": "mc-pod-1",
                    "port": 30001,
                }
            ]
        }
    }

@router.post("/")
def create_server(server: Server):
    crd_json = {
        "apiVersion": "charts.minecraft.net/v1alpha1",
        "kind": "Minecraft",
        "metadata": {
            "name": server.servername
        },
        "spec": {
            "minecraft": {
                "exposed_port": server.port,
                "motd": server.servername
            }
        }
    }

    k8s_api = client.CustomObjectsApi()
    group = "charts.minecraft.net"
    version = "v1alpha1"
    plural = "minecrafts"

    response = k8s_api.create_namespaced_custom_object(
        group, version, "default", plural, crd_json
    )

    print(response)
    return {"status": "OK"}

@router.delete("/{servername}")
def delete_server(servername: str = Path(..., description="The name of the Minecraft server")):
    group = "charts.minecraft.net"
    version = "v1alpha1"
    plural = "minecrafts"
    namespace = "default"

    k8s_api = client.CustomObjectsApi()

    try:
        response = k8s_api.delete_namespaced_custom_object(
            group, version, namespace, plural, servername
        )
        print(response)
        return {"status": "OK"}
    except client.rest.ApiException as e:
        if e.status == 404:
            raise HTTPException(status_code=404, detail=f"Server not found: {servername}")
        else:
            raise HTTPException(status_code=500, detail=f"Error deleting server: {str(e)}")

@router.get("/list")
def list_servers():
    group = "charts.minecraft.net"
    version = "v1alpha1"
    plural = "minecrafts"
    namespace = "default"

    k8s_api = client.CustomObjectsApi()

    try:
        server_list = k8s_api.list_namespaced_custom_object(
            group, version, namespace, plural
        )

        servers = []
        for server_item in server_list.get("items", []):
            server_attributes = server_item.get("spec", {}).get("minecraft", {})
            server = Server(servername=server_attributes.get("motd"), port=server_attributes.get("exposed_port"))
            servers.append(server)

        return {"servers": servers}
    except client.rest.ApiException as e:
        raise HTTPException(status_code=500, detail=f"Error listing servers: {str(e)}")

@router.get("/player-count/{servername}")
def get_player_count(servername: str = Path(..., description="The name of the Minecraft server")):
    group = "charts.minecraft.net"
    version = "v1alpha1"
    plural = "minecrafts"
    namespace = "default"

    core_api = client.CoreV1Api()

    try:
        label_selector = f"app=minecraft-server-{servername}"
        pods = core_api.list_namespaced_pod(namespace=namespace, label_selector=label_selector)

        if not pods.items:
            raise HTTPException(status_code=404, detail=f"No pod found for server: {servername}")

        pod_name = pods.items[0].metadata.name

        exec_command = ['/bin/sh', '-c', 'rcon-cli list']

        resp = stream(core_api.connect_get_namespaced_pod_exec,
                      pod_name,
                      namespace,
                      command=exec_command,
                      stderr=True, stdin=False,
                      stdout=True, tty=False)
        
        return {"Response": resp}
    except client.rest.ApiException as e:
        raise HTTPException(status_code=500, detail=f"Error executing command: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
