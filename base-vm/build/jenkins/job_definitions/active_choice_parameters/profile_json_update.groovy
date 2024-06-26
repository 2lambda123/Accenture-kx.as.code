import groovy.json.JsonSlurper
import groovy.json.JsonBuilder
import java.nio.file.Files
import java.nio.file.Paths
import java.nio.file.Path
import java.nio.file.StandardCopyOption

def BASE_DOMAIN
def BASE_USER
def ENVIRONMENT_PREFIX
def BASE_PASSWORD
def STANDALONE_MODE
def ALLOW_WORKLOADS_ON_KUBERNETES_MASTER
def DISABLE_LINUX_DESKTOP
def NUMBER_OF_KX_MAIN_NODES
def KX_MAIN_ADMIN_CPU_CORES
def KX_MAIN_ADMIN_MEMORY
def NUMBER_OF_KX_WORKER_NODES
def KX_WORKER_NODES_CPU_CORES
def KX_WORKER_NODES_MEMORY

def storageParameterElements
def generalParameterElements

def updatedJson
def parsedJson
def jsonFilePath = PROFILE.split(";")[0]
def profileStartMode = PROFILE.split(";")[1]
def orchestrator = PROFILE.split(";")[2]
def inputFile = new File(jsonFilePath)
def profileParentPath = inputFile.getParentFile().getName()
def profileName = inputFile.getName()

def templateName
def parsedTemplateJson
def jsonInputFile

def template_paths = []
def selectedTemplates = []
def profile_template_paths = []
def destinationFile
def alreadyExistingTemplateFilesInProfile = []

def currentDir = new File(".").getAbsolutePath().replaceAll("\\\\", "/")
currentDir = currentDir.substring(0, currentDir.length() - 1)

new File("${shared_workspace}/templates/").eachFileMatch(~/^aq.*.json$/) { template_paths << it.path }
new File("${shared_workspace}/profiles/${profileParentPath}/").eachFileMatch(~/^aq.*.json$/) { profile_template_paths << it.path }
selectedTemplates = TEMPLATE_SELECTOR.split(',');


try {
    if ( USER_PROVISIONING ) {
        def userJsonFilePath = "${shared_workspace}/profiles/${profileParentPath}/users.json"
        def parsedUserJson = new JsonSlurper().parseText(USER_PROVISIONING)
        new File(userJsonFilePath).write(new JsonBuilder(parsedUserJson).toPrettyString())
    }
} catch (e) {
    println("Something went wrong in the groovy user provisioning block (profile_json_update.groovy): ${e}")
}

try {
    if ( CUSTOM_VARIABLES ) {
        def customVariablesJsonFilePath = "${shared_workspace}/profiles/${profileParentPath}/customVariables.json"
        def parsedCustomVariablesJson = new JsonSlurper().parseText(CUSTOM_VARIABLES)
        new File(customVariablesJsonFilePath).write(new JsonBuilder(parsedCustomVariablesJson).toPrettyString())
    }
} catch (e) {
    println("Something went wrong in the groovy custom variables block (profile_json_update.groovy): ${e}")
}

def actionQueueFile;
switch (profileStartMode) {
    case "normal": actionQueueFile = "actionQueues.json";
        break;
    case "lite": actionQueueFile = "actionQueues.json_lite";
        break;
    case "minimal": actionQueueFile = "actionQueues.json_minimal";
        break;
}
def actionQueuePath = "${shared_workspace}/auto-setup/${actionQueueFile}";

try {
    try {
        Path sourcePath  = Paths.get(actionQueuePath);
        Path targetPath = Paths.get("${shared_workspace}/profiles/${profileParentPath}/actionQueues.json");
        Files.copy(sourcePath, targetPath, StandardCopyOption.REPLACE_EXISTING)
    } catch (IOException e) {
        println("Caught IOException when copying actionQueue")
    }
} catch (e) {
    println("Something went wrong in the groovy template block (profile_json_update.groovy): ${e}")
}

try {
    profile_template_paths.eachWithIndex { file, i ->
        try {
            Path fileToDelete = Paths.get(file)
            Files.delete(fileToDelete)
        } catch (IOException e) {
            println("Caught IOException when deleting template")
        }
    }
} catch (e) {
    println("Something went wrong in the groovy template block (profile_json_update.groovy): ${e}")
}

try {
    template_paths.eachWithIndex { file, i ->
        jsonInputFile = new File(file)
        parsedTemplateJson = new JsonSlurper().parse(jsonInputFile)
        templateName = parsedTemplateJson.title
        selectedTemplates.eachWithIndex { selectedTemplate, j ->
            if (selectedTemplate == templateName) {
                destinationFile = new File("${shared_workspace}/profiles/${profileParentPath}/${jsonInputFile.getName()}")
                try {
                    Files.copy(jsonInputFile.toPath(), destinationFile.toPath())
                } catch (IOException e) {
                    println("Caught IOException when copying template")
                }
            }
        }
    }
} catch (e) {
    println("Something went wrong in the groovy template block (profile_json_update.groovy): ${e}")
}

try {

    parsedJson = new JsonSlurper().parse(inputFile)

    parsedJson.config.startupMode = profileStartMode
    parsedJson.config.kubeOrchestrator = orchestrator

    if ( GENERAL_PARAMETERS ) {
        generalParameterElements = GENERAL_PARAMETERS.split(';')
        BASE_DOMAIN = generalParameterElements[0]
        ENVIRONMENT_PREFIX = generalParameterElements[1]
        BASE_USER = generalParameterElements[2]
        BASE_PASSWORD = generalParameterElements[3]
        STANDALONE_MODE = generalParameterElements[4]
        ALLOW_WORKLOADS_ON_KUBERNETES_MASTER = generalParameterElements[5]
        DISABLE_LINUX_DESKTOP = generalParameterElements[6]
    }

    if ( KX_MAIN_NODES_CONFIG ) {

        kxMainNodesConfigArray = KX_MAIN_NODES_CONFIG.split(';')
        NUMBER_OF_KX_MAIN_NODES = kxMainNodesConfigArray[0]
        KX_MAIN_ADMIN_CPU_CORES = kxMainNodesConfigArray[1]
        KX_MAIN_ADMIN_MEMORY = kxMainNodesConfigArray[2]
    }

    if ( KX_WORKER_NODES_CONFIG ) {
        kxWorkerNodesConfigArray = KX_WORKER_NODES_CONFIG.split(';')
        NUMBER_OF_KX_WORKER_NODES = kxWorkerNodesConfigArray[0]
        KX_WORKER_NODES_CPU_CORES = kxWorkerNodesConfigArray[1]
        KX_WORKER_NODES_MEMORY = kxWorkerNodesConfigArray[2]
    }

    if (STORAGE_PARAMETERS) {
        storageParameterElements = STORAGE_PARAMETERS.split(';')
    }

    def OLD_NUMBER_OF_KX_MAIN_NODES = parsedJson.config.vm_properties.main_node_count
    if (OLD_NUMBER_OF_KX_MAIN_NODES != NUMBER_OF_KX_MAIN_NODES && NUMBER_OF_KX_MAIN_NODES != "" && NUMBER_OF_KX_MAIN_NODES) {
        parsedJson.config.vm_properties.main_node_count = NUMBER_OF_KX_MAIN_NODES.toInteger()
    }

    def OLD_KX_MAIN_ADMIN_CPU_CORES = parsedJson.config.vm_properties.main_admin_node_cpu_cores
    if (OLD_KX_MAIN_ADMIN_CPU_CORES != KX_MAIN_ADMIN_CPU_CORES && KX_MAIN_ADMIN_CPU_CORES != "" && KX_MAIN_ADMIN_CPU_CORES) {
        parsedJson.config.vm_properties.main_admin_node_cpu_cores = KX_MAIN_ADMIN_CPU_CORES.toInteger()
    }

    def OLD_KX_MAIN_ADMIN_MEMORY = parsedJson.config.vm_properties.main_admin_node_memory
    if (OLD_KX_MAIN_ADMIN_MEMORY != KX_MAIN_ADMIN_MEMORY && KX_MAIN_ADMIN_MEMORY != "" && KX_MAIN_ADMIN_MEMORY) {
        parsedJson.config.vm_properties.main_admin_node_memory = KX_MAIN_ADMIN_MEMORY.toInteger()
    }

    def OLD_NUMBER_OF_KX_WORKER_NODES = parsedJson.config.vm_properties.worker_node_count
    if (OLD_NUMBER_OF_KX_WORKER_NODES != NUMBER_OF_KX_WORKER_NODES && NUMBER_OF_KX_WORKER_NODES != "" && NUMBER_OF_KX_WORKER_NODES) {
        parsedJson.config.vm_properties.worker_node_count = NUMBER_OF_KX_WORKER_NODES.toInteger()
    }

    def OLD_KX_WORKER_NODES_CPU_CORES = parsedJson.config.vm_properties.worker_node_cpu_cores
    if (OLD_KX_WORKER_NODES_CPU_CORES != KX_WORKER_NODES_CPU_CORES && KX_WORKER_NODES_CPU_CORES != "" && KX_WORKER_NODES_CPU_CORES) {
        parsedJson.config.vm_properties.worker_node_cpu_cores = KX_WORKER_NODES_CPU_CORES.toInteger()
    }

    def OLD_KX_WORKER_NODES_MEMORY = parsedJson.config.vm_properties.worker_node_memory
    if (OLD_KX_WORKER_NODES_MEMORY != KX_WORKER_NODES_MEMORY && KX_WORKER_NODES_MEMORY != "" && KX_WORKER_NODES_MEMORY) {
        parsedJson.config.vm_properties.worker_node_memory = KX_WORKER_NODES_MEMORY.toInteger()
    }

    if (TEMPLATE_SELECTOR) {
        def OLD_TEMPLATE_SELECTOR = parsedJson.config.selectedTemplates
        if (OLD_TEMPLATE_SELECTOR != TEMPLATE_SELECTOR && TEMPLATE_SELECTOR != "") {
            parsedJson.config.selectedTemplates = TEMPLATE_SELECTOR
        }
    } else {
        parsedJson.config.selectedTemplates = ""
    }

    if (BASE_DOMAIN) {
        def OLD_BASE_DOMAIN = parsedJson.config.baseDomain
        if (OLD_BASE_DOMAIN != BASE_DOMAIN && BASE_DOMAIN != "") {
            parsedJson.config.baseDomain = BASE_DOMAIN
        }
    } else {
        BASE_DOMAIN = parsedJson.config.baseDomain
    }

    if (ENVIRONMENT_PREFIX) {
        parsedJson.config.environmentPrefix = ENVIRONMENT_PREFIX
    } else {
        ENVIRONMENT_PREFIX = parsedJson.config.environmentPrefix
    }

    if (BASE_USER) {
        parsedJson.config.baseUser = "${BASE_USER}"
    } else {
        BASE_USER = parsedJson.config.baseUser
    }

    if (BASE_PASSWORD) {
        parsedJson.config.basePassword = "${BASE_PASSWORD}"
    } else {
        BASE_PASSWORD = parsedJson.config.basePassword
    }

    if (STANDALONE_MODE) {
        parsedJson.config.standaloneMode = STANDALONE_MODE
    } else {
        STANDALONE_MODE = parsedJson.config.standaloneMode
    }

    if (ALLOW_WORKLOADS_ON_KUBERNETES_MASTER) {
        parsedJson.config.allowWorkloadsOnMaster = ALLOW_WORKLOADS_ON_KUBERNETES_MASTER
    } else {
        ALLOW_WORKLOADS_ON_KUBERNETES_MASTER = parsedJson.config.allowWorkloadsOnMaster
    }

    if (DISABLE_LINUX_DESKTOP) {
        parsedJson.config.disableLinuxDesktop = DISABLE_LINUX_DESKTOP
    } else {
        DISABLE_LINUX_DESKTOP = parsedJson.config.disableLinuxDesktop
    }

    if (storageParameterElements) {
        def local_storage_num_one_gb = parsedJson.config.local_volumes.one_gb
        int number1GbVolumes = storageParameterElements[0].toInteger()
        if (local_storage_num_one_gb.toInteger() != number1GbVolumes && number1GbVolumes != "") {
            parsedJson.config.local_volumes.one_gb = number1GbVolumes
        }
        def local_storage_num_five_gb = parsedJson.config.local_volumes.five_gb
        int number5GbVolumes = storageParameterElements[1].toInteger()
        if (local_storage_num_five_gb.toInteger() != number5GbVolumes && number5GbVolumes != "") {
            parsedJson.config.local_volumes.five_gb = number5GbVolumes
        }
        def local_storage_num_ten_gb = parsedJson.config.local_volumes.ten_gb
        int number10GbVolumes = storageParameterElements[2].toInteger()
        if (local_storage_num_ten_gb.toInteger() != number10GbVolumes && number10GbVolumes != "") {
            parsedJson.config.local_volumes.ten_gb = number10GbVolumes
        }
        def local_storage_num_thirty_gb = parsedJson.config.local_volumes.thirty_gb
        int number30GbVolumes = storageParameterElements[3].toInteger()
        if (local_storage_num_thirty_gb.toInteger() != number30GbVolumes && number30GbVolumes != "") {
            parsedJson.config.local_volumes.thirty_gb = number30GbVolumes
        }
        def local_storage_num_fifty_gb = parsedJson.config.local_volumes.fifty_gb
        int number50GbVolumes = storageParameterElements[4].toInteger()
        if (local_storage_num_fifty_gb.toInteger() != number50GbVolumes && number50GbVolumes != "") {
            parsedJson.config.local_volumes.fifty_gb = number50GbVolumes
        }
        def OLD_NETWORK_STORAGE_OPTIONS = parsedJson.config.glusterFsDiskSize
        int NETWORK_STORAGE_OPTIONS = storageParameterElements[5].toInteger()
        if (OLD_NETWORK_STORAGE_OPTIONS != NETWORK_STORAGE_OPTIONS && NETWORK_STORAGE_OPTIONS != "") {
            parsedJson.config.glusterFsDiskSize = NETWORK_STORAGE_OPTIONS
        }
    }
    updatedJson = new JsonBuilder(parsedJson).toPrettyString()
    new File(jsonFilePath).write(new JsonBuilder(parsedJson).toPrettyString())
} catch(e) {
    println("Something went wrong in the GROOVY block (profile_json_update.groovy): ${e}")
}

try {
    // language=HTML
    def HTML = """
    <body>
    </body>
    """
    return HTML
} catch (e) {
    println("Something went wrong in the HTML return block (profile_json_update.groovy): ${e}")
}
