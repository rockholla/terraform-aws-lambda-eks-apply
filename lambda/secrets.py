from aws_lambda_powertools.utilities import parameters

def get_aws_secret(name):
  return parameters.get_secret(name)

if __name__=="__main__":
    result = get_aws_secret("alambeksa-example-dyn-a--4eks8")
    print(result)
