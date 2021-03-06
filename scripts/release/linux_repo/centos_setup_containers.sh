#!/bin/bash
sudo yum install -y createrepo wget rpm-sign

pushd /etc/yum.repos.d
sudo wget http://s3tools.org/repo/RHEL_6/s3tools.repo
sudo yum install -y s3cmd expect
popd 

cp ~/.ssh/live.s3cfg ~/.s3cfg

gpg --import ~/.ssh/79CF7903.priv.gpg 
gpg --import ~/.ssh/CD406E62.priv.gpg 
gpg --import ~/.ssh/D9223EDA.priv.gpg
