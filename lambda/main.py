"Lambda function to apply a k8s manifest (support for templated based on event data) to an EKS cluster"
import base64
import os
import logging
import subprocess

from jinja2 import Template
import secrets
import yaml

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, _context):
  "Lambda handler to recieve cluster information and a manifest template to apply to the EKS cluster"

  kubectl_result = ""
  try:
    token = secrets.get_aws_secret(event['cluster_token_secret_name'])
    cluster_connection_info = "endpoint: {}, ca: .......{}, token: *******{}".format(event["cluster_endpoint"], event['cluster_ca_certificate_data'][-5:], token[-5:])
    logger.info("Setting up Kubernetes client config for applying the manifest: {}".format(cluster_connection_info))
    kubeconfig = {
      'apiVersion': 'v1',
      'clusters': [{
        'name': 'thiscluster',
        'cluster': {
          'certificate-authority-data': event['cluster_ca_certificate_data'],
          'server': event["cluster_endpoint"]}
      }],
      'contexts': [{'name': 'thiscontext', 'context': {'cluster': 'thiscluster', "user": "thisuser"}}],
      'current-context': 'thiscontext',
      'kind': 'Config',
      'preferences': {},
      'users': [{'name': 'thisuser', "user" : {'token': token}}]
    }
    kubeconfig_path = "/tmp/kubeconfig"
    with open(kubeconfig_path, 'w') as kubeconfig_file:
      yaml.dump(kubeconfig, kubeconfig_file, default_flow_style=False)

    if 'secret_names' in event:
      for key, secret_name in event.items():
        logger.info("Getting secret: {}".format(secret_name))
        event[key] = secrets.get_aws_secret(secret_name)
    rendered_file_path = "/tmp/manifest.yaml"
    with open(rendered_file_path, 'w') as rendered_manifest_file:
      template = Template(base64.b64decode(event['manifest_template_base64']).decode('utf-8'))
      rendered_manifest = template.render(event)
      rendered_manifest_file.write(rendered_manifest)
    logger.info("Applying the rendered manifest")
    kubectl_result = subprocess.run(
      ['kubectl', '--kubeconfig', kubeconfig_path, 'apply', '-f', rendered_file_path],
      stdout=subprocess.PIPE,
      stderr=subprocess.STDOUT,
      text=True,
      check=True
    )
    kubectl_result.check_returncode()
    result = {
      'statusCode': 200,
      'body': kubectl_result.stdout
    }
    logger.info("Apply complete")
  except subprocess.CalledProcessError as e:
    error_result = "Error applying the manifest: {} {}".format(e.stdout, cluster_connection_info)
    logger.exception(error_result)
    result = {
      'statusCode': 500,
      'body': error_result
    }
  except Exception as e:
    error_result = "Error: {} {}".format(repr(e), cluster_connection_info)
    logger.exception(error_result)
    result = {
      'statusCode': 500,
      'body': error_result
    }
  finally:
    if os.path.exists(kubeconfig_path):
      os.remove(kubeconfig_path)
    if os.path.exists(rendered_file_path):
      os.remove(rendered_file_path)

  return result
