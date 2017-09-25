#!/bin/sh
REPO="com.ericsson.bss.rm.erms.gui" 
BRANCH=`git branch | grep \* | cut -d ' ' -f2`                                                              
if [ -z "${USERNAME}" ]; then                                                                               
        if [ -z "$1" ]; then
                echo -e "Please type your userId: \c"                                                       
                read username                                                                               
                if [ -z "$username" ]; then                                                                 
                        echo "Error: Unable to determine your user name"                                    
                        exit 1                                                                              
                fi                                                                                          
                USERNAME=$username                                                                          
        else                                                                                                
                USERNAME=$1                                                                                 
        fi                                                                                                  
fi                                                                                                          
                                                                                                            
mkdir -p .git/hooks/                                                                                        
                                                                                                            
scp -p -P 29418 ${USERNAME}@gerrit.epk.ericsson.se:hooks/commit-msg .git/hooks/                             
                                                                                                            
git config --unset remote.review.url                                                                        
git config --unset remote.review.push                                                                       
                                                                                                            
git remote add review ssh://${USERNAME}@gerrit.epk.ericsson.se:29418/erms/${REPO}                           
                                                                                                            
if [ ${?} != 0 ]; then                                                                                      
  echo "Error: GIT configuration was not updated"                                                           
  exit 1                                                                                                    
fi                                                                                                          
git config --unset remote.review.fetch                                                                      
git config --add remote.review.push "+HEAD:refs/for/$BRANCH"                                                
echo -e "\nAdded review branch configuration\n"                                                             
git config -l | grep remote.review                                                                          
