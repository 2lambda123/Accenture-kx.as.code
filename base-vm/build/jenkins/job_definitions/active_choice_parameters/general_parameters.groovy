import groovy.json.JsonSlurper

def infoTextBaseDomain
def infoTextBaseUser
def infoTextEnvironmentPrefix
def infoTextBasePassword
def config_baseDomain
def config_environmentPrefix
def config_baseUser
def config_basePassword
def config_startupMode
def config_allowWorkloadsOnMaster
def config_disableLinuxDesktop
def config_standaloneMode
def generalParamsExtendedDescription

try {
    def jsonFilePath = PROFILE.split(";")[0]
    def inputFile = new File(jsonFilePath)
    parsedJson = new JsonSlurper().parse(inputFile)
} catch(e) {
    println "Something went wrong in the GROOVY block (general_parameters.groovy): ${e}"
}

try {
    infoTextBaseDomain = "<p class='info-text-header'>[do‧ma‧in] /d̪oˈmaɪn/</p><p class='info-text-body'>This describes the domain name that all deployed services will be reachable by. Default is &quot;kx-as-code.local&quot;</p>"
    infoTextBaseUser = "<p class='info-text-header'>[us‧er] /ˈjuːzə/</p><p class='info-text-body'>The initial admin user for the base workstation. Default is &quot;kx.hero&quot;"
    infoTextEnvironmentPrefix = "<p class='info-text-header'>[team] /tiːm/</p><p class='info-text-body'>The additional sub-domain prepended to the base domain. This ensures separation where there are multiple deployments"
    infoTextBasePassword = "<p class='info-text-header'>[pass‧word] /pæswɜːɹd/</p><p class='info-text-body'>The initial password for the base workstation. Default is &quot;L3arnandshare&quot;"

    config_baseDomain = parsedJson.config.baseDomain
    config_environmentPrefix = parsedJson.config.environmentPrefix
    config_baseUser = parsedJson.config.baseUser
    config_basePassword = parsedJson.config.basePassword
    config_allowWorkloadsOnMaster = parsedJson.config.allowWorkloadsOnMaster
    config_disableLinuxDesktop = parsedJson.config.disableLinuxDesktop
    config_standaloneMode = parsedJson.config.standaloneMode
    config_startupMode = parsedJson.config.startupMode

    generalParamsExtendedDescription = "In this panel you set the parameters that define how the internal DNS of KX.AS.CODE will be configured. Each new service that is provisioned in KX.AS.CODE will have the fully qualified domain name (FQDN) of &lt;service_name&gt;.&lt;team_name&gt;.&lt;base_domain&gt;. The username and password fields determine the base admin user password. It is possible to add additional users. In the last section, you determine if running in standalone or cluster mode. Standalone mode starts up one main node only. This is recommended for any physical environment with less than 16G ram. If enable worker nodes,then you can also choose to have workloads running on both main and worker nodes, or only on worker nodes."

} catch(e) {
    println("Something went wrong in the GROOVY block (general_parameters.groovy): ${e}")
}

def infoTextStandaloneMode = "Determines whether to run with a single main node or with additional worker nodes. This will automatically set KX-Workers to zero, Kx-Main to 1, and ensures \"Allow Workloads on Kubernetes Master\" is set to true"
def infoTextWorkloadOnMaster = "Determines whether workloads will be permitted on master nodes or not. Only set this to false if you start KX.AS.CODE with worker nodes"
def standaloneModeExtendedDescription = "If you set standalone mode to true, then the number of main nodes is automatically set to 1, and worked nodes set to 0 and disabled completely. If you have only build the main Vagrant box so far, then standalone mode will be enabled automatically"
def infoTexDisableDesktop = "Recommended if you are really low on resources. Disabling the KDE Plasma Desktop will save some CPU and memory. You can still start the desktop manually by typing \"<i>startx</i>\" on the command line once KX.AS.CODE is up"

try {
    // language=HTML
    def HTML = """
    <div id="general-parameters-div" style="display: none;">
        <h1>General Parameters and Mode Selection</h1>
        <span class="description-paragraph-span"><p>${generalParamsExtendedDescription}</p></span>
        <h2>General Profile Parameters</h2>
        <p style="margin-bottom: 20px">Changing the general parameters is optional. If you enter a base domain name, make sure it is a valid FQDN according to RFC1035</p>
        <div class="input-box-div">
            <span class="input-box-span">
                <label for="general-param-base-domain" class="input-box-label">Base Domain</label>
                <input class="input-box" id="general-param-base-domain" type="text" placeholder="${config_baseDomain}" value="${config_baseDomain}" onchange="updateConcatenatedGeneralParamsReturnVariable();">
                <div class="tooltip-info"><span class="info-span"><img src="/userContent/icons/information-variant.svg" class="info-icon" alt="info"><span class="tooltiptext">${infoTextBaseDomain}</span></span></div>
            </span>
            <span class="input-box-span">
                <label for="general-param-username" class="input-box-label">Username</label>
                <input class="input-box" id="general-param-username" type="text" placeholder="${config_baseUser}" value="${config_baseUser}" onchange="updateConcatenatedGeneralParamsReturnVariable();">
                <div class="tooltip-info"><span class="info-span"><img src="/userContent/icons/information-variant.svg" class="info-icon" alt="info"><span class="tooltiptext">${infoTextBaseUser}</span></span></div>
            </span>
        </div>
        <div class="input-box-div">
            <span class="input-box-span">
                <label for="general-param-team-name" class="input-box-label">Team Name</label>
                <input class="input-box" id="general-param-team-name" type="text" placeholder="${config_environmentPrefix}" value="${config_environmentPrefix}" onchange="updateConcatenatedGeneralParamsReturnVariable();">
                <div class="tooltip-info"><span class="info-span"><img src="/userContent/icons/information-variant.svg" class="info-icon" alt="info"><span class="tooltiptext">${infoTextEnvironmentPrefix}</span></span></div>
                <br><a onClick="generateTeamName();" style="cursor: pointer; cursor: hand; color: var(--kx-material-primary-70);"><img src="/userContent/icons/refresh.svg" class="info-icon svg-blue" alt="info">Generate Team Name</a>
            </span>
            <span class="input-box-span" style="vertical-align: middle;">
                <label for="general-param-password" class="input-box-label">Password</label>
                <span><input class="input-box password-input-box" id="general-param-password" type="password" placeholder="${config_basePassword}" value="${config_basePassword}" onchange="updateConcatenatedGeneralParamsReturnVariable();"></span><span class="password-show-hide-icon" onclick="showHidePassword()"><img id="general-param-password-svg" src="/userContent/icons/eye-outline.svg" class="svg-blue password-show-hide-icon-svg"></span>
                <div class="tooltip-info"><span class="info-span"><img src="/userContent/icons/information-variant.svg" class="info-icon" alt="info"><span class="tooltiptext">${infoTextBasePassword}</span></span></div>
                <br><a onClick="generatePassword();" style="cursor: pointer; cursor: hand; color: var(--kx-material-primary-70);"><img src="/userContent/icons/refresh.svg" class="info-icon svg-blue" alt="info">Generate Password</a>
            </span>
        </div>
    </div>

    <div id="standalone-toggle-div" style="display: none;">
        <br>
        <h2>Additional Toggles</h2>
        <p>
        ${standaloneModeExtendedDescription}
        </p>
        <div class="wrapper">
            <span class="span-toggle-text">Enable Standalone Mode</span><label for="general-param-standalone-mode-toggle" class="checkbox-switch">
            <input class="checkbox-slider round" type="checkbox" onclick="updateCheckbox(this.id); updateConcatenatedGeneralParamsReturnVariable();" id="general-param-standalone-mode-toggle" value="${config_standaloneMode}" checked="${config_standaloneMode}">
            <span class="checkbox-slider round" id="general-param-standalone-mode-toggle-span" ></span></label>
            <span class="tooltip-info"><span class="info-span"><img src="/userContent/icons/information-variant.svg" class="info-icon" alt="info"><span class="tooltiptext">${infoTextStandaloneMode}</span></span></span>
            <style scoped="scoped" onload="setInitialCheckboxValue('general-param-standalone-mode-toggle', ${config_standaloneMode});">   </style>
         </div>
    </div>

    <div class="outerWrapper" id="workloads-on-master-div" style="display: none">
        <div class="wrapper">
            <span class="span-toggle-text">Allow Workloads on Kubernetes Master</span><label for="general-param-workloads-on-master-toggle" class="checkbox-switch">
            <input class="checkbox-slider round" type="checkbox" onclick="updateCheckbox(this.id); updateConcatenatedGeneralParamsReturnVariable();" id="general-param-workloads-on-master-toggle" value="${config_allowWorkloadsOnMaster}" checked="${config_allowWorkloadsOnMaster}">
            <span class="checkbox-slider round" id="general-param-workloads-on-master-toggle-span" ></span></label>
            <span class="tooltip-info"><span class="info-span"><img src="/userContent/icons/information-variant.svg" class="info-icon" alt="info"><span class="tooltiptext">${infoTextWorkloadOnMaster}</span></span></span>
            <style scoped="scoped" onload="setInitialCheckboxValue('general-param-workloads-on-master-toggle', ${config_allowWorkloadsOnMaster});">   </style>
        </div>
    </div>

    <div class="outerWrapper" id="disable-desktop-div" style="display: none">
        <div class="wrapper">
            <span class="span-toggle-text">Disable Linux Desktop</span><label for="general-param-disable-desktop-toggle" class="checkbox-switch">
            <input class="checkbox-slider round" type="checkbox" onclick="updateCheckbox(this.id); updateConcatenatedGeneralParamsReturnVariable();" id="general-param-disable-desktop-toggle" value="${config_disableLinuxDesktop}" checked="${config_disableLinuxDesktop}">
            <span class="checkbox-slider round" id="general-param-disable-desktop-toggle-span" ></span></label>
            <span class="tooltip-info"><span class="info-span"><img src="/userContent/icons/information-variant.svg" class="info-icon" alt="info"><span class="tooltiptext">${infoTexDisableDesktop}</span></span></span>
            <style scoped="scoped" onload="setInitialCheckboxValue('general-param-disable-desktop-toggle', ${config_disableLinuxDesktop});">   </style>
        </div>
    </div>

    <input type="hidden" id="general-param-standalone-mode-toggle-name-value" name="general-param-standalone-mode-toggle-name-value" value="${config_standaloneMode}">
    <input type="hidden" id="general-param-workloads-on-master-toggle-name-value" name="general-param-workloads-on-master-toggle-name-value" value="${config_allowWorkloadsOnMaster}">
    <input type="hidden" id="general-param-disable-desktop-toggle-name-value" name="general-param-disable-desktop-toggle-name-value" value="${config_disableLinuxDesktop}">
    <input type="hidden" id="concatenated-general-params" name="value" value="" >
    <!-- <style scoped="scoped" onload="updateStartModeSelection('${config_startupMode}'); updateConcatenatedGeneralParamsReturnVariable();">   </style> -->
    """
    return HTML
} catch (e) {
    println "Something went wrong in the HTML return block (general_parameters.groovy): ${e}"
}
