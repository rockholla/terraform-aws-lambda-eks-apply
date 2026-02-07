from aws_lambda_powertools.utilities import parameters

def get_aws_secret(name):
  return parameters.get_secret(name=name, force_fetch=True)
