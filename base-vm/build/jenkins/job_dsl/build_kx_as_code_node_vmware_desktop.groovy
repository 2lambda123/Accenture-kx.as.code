import jenkins.model.Jenkins
import hudson.model.Item
import hudson.model.Items

def jobProperties
Item currentJob = Jenkins.instance.getItemByFullName('VMWare_Workstation/GeneratedJobs/02_Build_KX.AS.CODE_Node')
if (currentJob) {
  jobProperties = currentJob.@properties
}

jobProperties.each {
   println "${it.dump()}"
}

pipelineJob('VMWare_Workstation/GeneratedJobs/02_Build_KX.AS.CODE_Node') {
    definition {
      cps {
        script(readFileFromWorkspace('base-vm/build/jenkins/pipelines/build-kx.as.code-node-vmware-desktop.Jenkinsfile'))
        sandbox()
      }
      queue("VMWare_Workstation/GeneratedJobs/02_Build_KX.AS.CODE_Node")
      if (jobProperties) {
      configure { root ->
        def properties = root / 'properties'
        jobProperties.each { property ->
          String xml = Items.XSTREAM2.toXML(property)
          def jobPropertiesPropertyNode = new XmlParser().parseText(xml)
          properties << jobPropertiesPropertyNode
        }
      }
    }
  }
}
