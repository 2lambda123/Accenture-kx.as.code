import jenkins.model.Jenkins
import hudson.model.Item
import hudson.model.Items

def jobProperties
Item currentJob = Jenkins.instance.getItemByFullName('OpenStack/GeneratedJobs/01_Build_KX.AS.CODE_Main')
if (currentJob) {
  jobProperties = currentJob.@properties
}

jobProperties.each {
   println "${it.dump()}"
}

pipelineJob('OpenStack/GeneratedJobs/01_Build_KX.AS.CODE_Main') {
    definition {
      cps {
        script(readFileFromWorkspace('base-vm/build/jenkins/pipelines/build-kx.as.code-main-openstack.Jenkinsfile'))
        sandbox()
      }
      queue("OpenStack/GeneratedJobs/01_Build_KX.AS.CODE_Main")
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