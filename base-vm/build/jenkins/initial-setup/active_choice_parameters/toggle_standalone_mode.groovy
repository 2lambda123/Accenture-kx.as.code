import groovy.json.JsonSlurper

def standaloneMode
def infoText
def extendedDescription
def cssClass

println("PREREQUISITES_CHECK: *${PREREQUISITES_CHECK}*")

if (PREREQUISITES_CHECK != "failed") {
    try {
        if (PREREQUISITES_CHECK == "standalone") {
            standaloneMode = true
            cssClass = "checkbox-slider-checked-disabled round"
            println("Inside standalone = true...")
        } else {
            println("Inside standalone = false...")
            def jsonFilePath = PROFILE
            def inputFile = new File(jsonFilePath)
            def parsedJson = new JsonSlurper().parse(inputFile)
            standaloneMode = parsedJson.config.standaloneMode
            cssClass = "checkbox-slider round"
        }

        infoText = "Determines whether to run with a single main node or node. This will automatically set KX-Workers to zero, Kx-Main to 1, and ensure allow-workloads on master is set to 1"
        extendedDescription = "If you set standalone mode to true, then the number of main nodes is automatically set to 1, and worked nodes set to 0 and disabled completely. If you have only build the main Vagrant box so far, then standalone mode will be enabled automatically"
    } catch(e) {
        println("Something went wrong in the GROOVY block (toggle_standalone_mode): ${e}")
    }
    try {
        // language=HTML
        def HTML = """
        <body>
        <div id="standalone-toggle-div" style="display: none;">
            <h2>Standalone or Cluster Mode</h2>
            <p>
            ${extendedDescription}
            </p>
            <div class="wrapper">
                <span class="span-toggle-text">Enable Standalone Mode</span><label for="standalone-mode-toggle" class="checkbox-switch">
                <input type="checkbox" onclick="updateCheckbox(this.id)" id="standalone-mode-toggle" value="${standaloneMode}" checked=${standaloneMode}>
                <span class="${cssClass}" id="standalone-mode-toggle-span"></span>
            </label><span class="info-span"><img src="/userContent/icons/information-variant.svg" class="info-icon" alt="${infoText}"></span>
            </div>
            <style scoped="scoped" onload="updateCheckbox('standalone-mode-toggle');">   </style>
        </div>
        <input type="hidden" id="standalone-mode-toggle-name-value" name="value" value="${standaloneMode}">
        </body>
        """
        return HTML
    } catch (e) {
        println("Something went wrong in the HTML return block (toggle_standalone_mode): ${e}");
    }

}
