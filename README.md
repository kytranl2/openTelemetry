mvn clean package 



aws configure


aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 851725314367.dkr.ecr.us-east-1.amazonaws.com


NOTE: If you need the image to support multiple architectures (x86_64 and arm64), use Docker Buildx.


docker buildx create --use



docker buildx build --platform linux/amd64,linux/arm64 \
  -t 851725314367.dkr.ecr.us-east-1.amazonaws.com/telemetry-springboot:latest \
  --push .


docker build -t springboot-app:latest .


docker tag springboot-app:latest 8851725314367.dkr.ecr.us-east-1.amazonaws.com/telemetry-springboot:latest






terraform init 

terraform plan

terraform apply


ssh -i /path/to/your/key.pem ec2-user@<public-ip-address>

ssh -i my-ec2-efs-keypair.pem ec2-user@54.196.84.40


zsh - scp -i /path/to/your/key.pem otel-collector-config.yaml ec2-user@<public-ip-address>:/home/ec2-user/


ssh - sudo mv /home/ec2-user/otel-collector-config.yaml /mnt/efs/otel-config/

ssh - sudo mount -t efs -o tls,accesspoint=fsap-02d000e0b5c685231 fs-03b24066c0d89a72f:/ /mnt/test-efs

sudo mount -t efs -o tls,accesspoint=fsap-02d000e0b5c685231 fs-03b24066c0d89a72f:/ /mnt/efs


