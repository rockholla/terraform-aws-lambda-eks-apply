# test/mocked version of the get_secret_name method so we can
# not rely on AWS integration for local tests
def get_aws_secret(name):
  return name
