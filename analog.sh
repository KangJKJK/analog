#!/bin/bash

# 굵은 글씨와 색상 정의
BOLD="\033[1m"
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}아날로그 노드설치를 시작합니다...${NC}"

# 시스템 종속성 업데이트
echo -e "${BLUE}시스템 종속성을 업데이트 중입니다...${NC}"
echo
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
echo

# 도커 설치 확인
echo -e "${BOLD}${CYAN}Docker 설치 확인 중...${NC}"
if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}Docker가 이미 설치되어 있습니다.${NC}"
else
    echo -e "${RED}Docker가 설치되어 있지 않습니다. Docker를 설치하는 중입니다...${NC}"
    sudo apt update && sudo apt install -y curl net-tools
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    echo -e "${GREEN}Docker가 성공적으로 설치되었습니다.${NC}"
fi

# Docker 설치 확인
echo -e "${BLUE}Docker 설치를 확인 중입니다...${NC}"
echo
sudo docker run hello-world
echo

# Analog Timechain Docker 이미지 가져오기
echo -e "${BLUE}Analog Timechain Docker 이미지를 가져오는 중입니다...${NC}"
echo
docker pull analoglabs/timechain
echo

# NODE_NAME 변수 설정
echo -e "${BLUE}NODE_NAME 변수를 설정 중입니다...${NC}"
echo
read -p "노드에 사용할 이름을 입력하세요: " NODE_NAME
echo "export NODE_NAME=\"$NODE_NAME\"" >> ~/.bash_profile
source ~/.bash_profile
echo
echo -e "${BLUE}노드 이름을 기억해야 하며, 화이트리스트 폼 제출 시 필요합니다.${NC}"
echo

# 5. UFW 설치 및 포트 개방
execute_with_prompt "UFW 설치 중..." "sudo apt-get install -y ufw"
execute_with_prompt "필요한 포트 개방 중..." \
    "sudo ufw enable && \
    sudo ufw allow ssh && \
    sudo ufw allow 9944/tcp && \
    sudo ufw allow 30303/tcp && \"

# Analog Timechain Docker 컨테이너 실행
echo -e "${BLUE}Analog Timechain Docker 컨테이너를 실행 중입니다...${NC}"
echo
docker run -d --name analog -p 9944:9944 -p 30303:30303 analoglabs/timechain \
    --base-path /data \
    --rpc-external \
    --unsafe-rpc-external \
    --rpc-cors all \
    --name $NODE_NAME \
    --telemetry-url="wss://telemetry.analog.one/submit 9" \
    --rpc-methods Unsafe
echo

# websocat 설치
echo -e "${BLUE}websocat을 설치 중입니다...${NC}"
sudo wget -qO /usr/local/bin/websocat https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl
sudo chmod a+x /usr/local/bin/websocat
echo

# websocat 버전 확인
echo -e "${BLUE}websocat 버전을 확인 중입니다...${NC}"
echo
websocat --version
if [ $? -ne 0 ]; then
    echo "websocat 설치 실패 또는 경로에 없습니다."
    exit 1
fi
echo

# jq 설치
sudo apt-get install jq

# 잠시 대기
sleep 2

# websocat을 사용하여 로테이션키를 생성중입니다.
echo -e "${BLUE}websocat을 사용하여 로테이션키를 생성중입니다...${NC}"
echo
RESPONSE=$(echo '{"id":1,"jsonrpc":"2.0","method":"author_rotateKeys","params":[]}' | websocat -n1 -B 99999999 ws://127.0.0.1:9944)
if [ $? -ne 0 ]; then
    echo "websocat을 사용하여 로테이션키를 생성하는데 실패하였습니다."
    exit 1
fi
KEY=$(echo $RESPONSE | jq -r '.result')
echo -e "로테이션키는 다음과 같습니다: ${GREEN}$KEY${NC}"
read -p "로테이션키를 따로 저장해두시고 엔터를 눌러주세요: "

echo -e "${BOLD}FAUCET 과정을 진행합니다..${NC}"
echo -e "${YELLOW}해당 사이트로 이동하여 주세요: hhttps://polkadot.js.org/apps/?rpc=wss%3A%2F%2Frpc.testnet.analog.one#/accounts${NC}"
echo -e "${YELLOW}계정들을 눌러서 계정을 생성하거나 기존에 있던 계정의 주소를 확인해주세요.${NC}"
echo -e "${YELLOW}가이드에따라 Faucet을 받아주세요: https://docs.analog.one/documentation/resources/tooling/utilities/testnet-faucet${NC}"
read -p "Faucet을 받으시면 엔터를 눌러주세요: "

echo -e "${BOLD}밸리데이터 등록을 진행합니다..${NC}"
echo -e "${YELLOW}해당 사이트로 이동하여 주세요: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Frpc.testnet.analog.one#/staking/actions${NC}"
echo -e "${YELLOW}Validator오른쪽 상단 모서리에 있는 옵션 을 클릭하세요${NC}"
echo -e "${YELLOW}stash account아날로그 지갑을 선택하고 기타 세부 정보는 기본값으로 유지하세요.${NC}"
echo -e "${YELLOW}다음버튼을 클릭한 후 keys from rotatekeys에 위에서 저장한 당신의 로테이션키를 적으세요.${NC}"
echo -e "${YELLOW}리워드 커미션은 1~10 사이의 수 중 자유롭게 선택하세요.${NC}"
read -p "Bond & Validate를 클릭한 후 엔터를 눌러주세요: "

# 작업 완료 메시지
echo -e "${GREEN}해당 사이트로 접속하여 구글폼을 반드시 남기고 팀의 승인을 기다리세요.${NC}"
echo -e "${YELLOW}https://l5d87lam6fy.typeform.com/to/kwlADm6U?typeform-source=docs.analog.one.${NC}"
echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
