#!/bin/bash


#####################
## common functions #
#####################

raise_error(){
    echo -e "\e[1;31m$*\e[0m"
    exit 2
}

inform(){
    echo -e "\e[1;32m$*\e[0m"
}

usage(){
    echo -e "\tUsage:"
    echo -e "\t\t./$0 --java_path JAVA_PATH --java_package_url JAVA_PACKAGE_URL"
    exit 1
}

handle_params(){
    PARAM_NUM=$#
    set -- "$@"

    [ $PARAM_NUM -gt 0 ] && while true; do
        case "$1" in
            -t|--time)
                curtime=${2:?"Param losted"}
                echo $curtime
                shift 2
                ;;
            -m|--month)
                month=true
                echo $month
                shift 1
                ;;
            *)
                remand_args="$@"
                break;;
        esac
    done
}
handle_params "$@"



######################
## common components #
######################

install_java(){
    ###############################################
    ## usage:                                     #
    ## install_java install_path java_package_url #
    ###############################################

    # check whether java already installed
    command -v java > /dev/null && { inform "Java Runtime Environment alreadly satisfied!"; return;}
    ## install Java
    # prepare variables
    java_install_path=${1:-"/usr/local/java"}
    defalut_package_url="ftp://192.168.31.84/0.Sharplook_Release/OpenSource/jdk-8u261-linux-x64.tar.gz"
    package_url=${2:-$defalut_package_url}
    java_tar_file=${package_url##.*/}
    # start install java
    mkdir -p $java_install_path
    rm -rf $java_tar_file
    # Download package
    wget $package_url && test -e $java_tar_file || raise_error "Download Java package failed!"
    # untar package
    tar -zxf $java_tar_file -C $java_install_path
    jdk_path=$java_install_path/jdk1.8.0_201
    test -f $JAVA_HOME || raise_error "Java application package looks like untar fialed as the specified folder not exist!"
    # environment setting
    cat >> /etc/profile <<-EOCAT
    export JAVA_HOME=$jdk_path
    export JRE_HOME=$JAVA_HOME/jre
    export CLASSPATH=$CLASSPATH:$JAVA_HOME/jre/lib
    export PATH=$JAVA_HOME/bin:$PATH
    EOCAT
    # check install result
    export JAVA_HOME=$jdk_path
    export JRE_HOME=$JAVA_HOME/jre
    export CLASSPATH=$CLASSPATH:$JAVA_HOME/jre/lib
    export PATH=$JAVA_HOME/bin:$PATH
    command -v java > /dev/null && inform "Java install successfule!" || raise_error "Java install failed!"
}


######################
## project functions #
######################

install_docker(){
    ###############################################
    ## usage:                                     #
    ## install_docker
    ###############################################
    command -v docker > /dev/null && { inform "docker application alreadly satisfied!"; return;}
    install_path=${1:-"/usr/local/docker"}
    defalut_package_url="ftp://192.168.31.84/vision/app/docker/docker-18.09.5.tgz"
    package_url=${2:-$defalut_package_url}
    docker_tar_file=${package_url##*/}
    docker_path=$install_path/docker
    # Start install docker
    mkdir -p $install_path
    # Download docker package
    wget $package_url && test -e $docker_tar_file || raise_error "Download docker package failed!"
    # untar package
    tar -zxf $docker_tar_file -C $install_path
    test -d $docker_path && inform "Docker package untar successful!" || raise_error "Docker package untar error!"
    # Set environment
    echo 'export PATH=$PATH:$docker_path' >> /etc/profile
    export PATH=$PATH:$docker_path
    command -v docker > /dev/null && inform "Docker install successfule!" || raise_error "Dcoker install failed!"
}

launch_dockerd(){
    ###############################################
    ## usage:                                     #
    ## launch_dockerd
    ###############################################
    # make sure dockerd is active
    install_path=${1:-"/usr/local/docker"}
    docker_path=$install_path/docker
    # check whether docker installed
    command -v docker > /dev/null || install_docker
    # launch dockerd
    for i in 10 20 30 ; do
        docker ps &> /dev/null && break || { mkdir -p /var/log; nohup $docker_path/dockerd &> /var/log/docker.log &; sleep $i; }
    done
    # check result
    sleep 10 # dockerd will auto exit while it encounter unexpected error
    ps aux | grep -v grep | grep dockerd && inform "Dockerd launched successful!" || raise_error "Dcokerd launched failed!"
}

install_algorithm(){
    ###############################################
    ## usage:                                     #
    ## install_algorithm
    ###############################################
    ## pyenv prepare
    # python environment image url
    pyenv_image_name=jax_pyenv_img
    pyenv_tar_url=${1:-"ftp://192.168.31.84/Deploy/sensor/python/env/jax_pyenv.tar"}
    pyenv_tar_file=${pyenv_tar_url##*/}
    # pyenv_path=$PWD
    # load pyenv image
    docker images | grep $pyenv_image_name && {
        wget $pyenv_tar_url
        test -f $pyenv_tar_file || raise_error "pyenv image download failed!"
        docker load -i $pyenv_tar_file $pyenv_image_name
        docker images | grep $pyenv_image_name || raise_error "pyenv docker image load failed!"
    }
    ## install pyenv service
    pyenv_service_url=${2:-"ftp://192.168.31.84/0.Sharplook_Release/Sensor/4.1/jax-algorithm_1.0.0.tar.gz"}
    pyenv_service_file=${pyenv_service_url##*/}
    pyenv_service_path=${3:-$PWD/jax-algorithm}
    # download service file
    wget $pyenv_service_url
    test -f $pyenv_service_file || raise_error "Download pyenv service file failed!"
    # untar service file
    mkdir -p $pyenv_service_path
    tar -zxf $pyenv_service_file -C $pyenv_service_path
    test -d $pyenv_service_path || raise_error "Untar pyenv service file failed!"
    ## edit config
    setting_config_file=$pyenv_service_path/web/web/settings.py
    dbIP=${4:-"192.168.21.58"}
    dbPORT=${5:-5433}
    dbNAME=${6:-"dbadmin"}
    dbTABLE[1]=${a:-"sensor_dt_source"}
    dbTABLE[2]=${a:-"sensor_dt_result_online"}
    dbUSER=${7:-"dbadmin"}
    dbPASSWD=${8:-"123456"}
    sed -i 's/(\"host\": ?).*/'$dbIP'/' $setting_config_file
    sed -i 's/(\"port\": ?).*/'$dbPORT'/' $setting_config_file
    sed -i 's/(\"database\": ?).*/'$dbNAME'/' $setting_config_file
    # sed -i 's/(\"table\": ).*/'$dbTALBE'/' $setting_config_file
    sed -i 's/(\"username\": ?).*/'$dbUSER'/' $setting_config_file
    sed -i 's/(\"password\": ?).*/'$dbPASSWD'/' $setting_config_file
    # launch pyenv service
    pyenv_service_container_name=jax_pyenv
    cd $pyenv_service_path
    docker ps | grep $pyenv_service_container_name && docker kill $pyenv_service_container_name
    sleep 2
    ./start.sh  # warn: keyword jax_pyenv in this script
    # check result
    docker ps | grep $pyenv_service_container_name || inform "pyenv service launch successful!" || raise_error "pyenv service launch failed!"
    cd -
}

install_sensor(){
    ##########################
    # install sensor
    # usage:
    # install_sensor sensor_package_url
    #########################
    sensor_package_url=${1:-"ftp://192.168.31.84/0.Sharplook_Release/Sensor/4.1/sensor-4.1.9-20200930-91b64db5.tar.gz"}
    sensor_package_file=${sensor_package_url##*/}
    sensor_install_path=${2:-$PWD}
    JVM1=${3:-1024}
    JVM2=${4:-1024}

    # download sensor package file
    wget $sensor_package_url > /dev/null
    tar -zxf $sensor_package_file -C $sensor_install_path

    ## generator config

    ## prepare database
    # init vertica database
    # init mysql database
    cd $sensor_install_path/sensor
    ProgramJar=$sensor_install_path/sensor/sensor-server-*.jar
    LoggingConfig=$sensor_install_path/sensor/logback-spring.xml
    SENSOR_JAVA_OPTS="-Xmx${JVM1}m -Xms${JVM2}m"
    test -z $JAVA_HOME && source /etc/profile
    test -x "$JAVA_HOME/bin/java" && JAVA="$JAVA_HOME/bin/java" || JAVA=`which java`
    exec "$JAVA" -jar $SENSOR_JAVA_OPTS -Dlogging.config=${LoggingConfig} ${ProgramJar} "$@" <&- &
    cd -
    jps | grep $ProgramJar || inform "Sensor service launch successful!" || raise_error "Sensor service launch failed!"
}

generator_config(){

cat >> application.yml <<EOCAT
server:
  port: 9088
  advertised:
    address:
    port:

sensor:
  serverId: 1
  verticaSchema: public
  unified:
    enable: true
    server:
      name: authentication
    timeoutSeconds: 300
    serviceName: dealAnalysis
  jax:
    server:
      name: jax
    timeoutSeconds: 300
  es:
    timeoutSeconds: 60
    scrollSize: 5000
  kafka:
    server: localhost:9092
    timeoutSeconds: 5
  predict:
    kafkaServer: ${sensor.kafka.server}
    kafkaTopic: sensor-predict
  alert:
    kafkaServer: ${sensor.kafka.server}
    kafkaTopic: sensor-alert
  offline:
    kafkaServer: ${sensor.kafka.server}
    kafkaTopic: sensor-offline-detect
  online:
    kafkaServer: ${sensor.kafka.server}
    kafkaTopic: sensor-online-detect
    pipeline:
      warmUpEnabled: true
  sync:
    kafkaServer: ${sensor.kafka.server}
    kafkaTopic: sensor-sync-data
    health:
      intervalSecond: 60
      schema: sensor_sched
  view:
    remote:
      server: localhost:8001
      timeoutSeconds: 1800
  thread:
    corePoolSize: 5
    maxPoolSize: 100
    keepAliveTime: 60
    queueCapacity: 50
    threadNamePrefix: SensorThread_
  cron:
    health: 0 %s 0/1 * * ? *
    poll: 0 * * * * ?
  publicKey: publicKey
  privateKey: privateKey
  model:
    storage:
      type: redis
  redis:
    type: sentinel
  cmdb:
    serviceName: cmdb
  kerberos:
    service:
      name: kafka

mybatis-plus:
  configuration:
    cache-enabled: true
    jdbc-type-for-null: 'null'
  global-config:
    db-config:
      column-format: '%s'
      table-prefix: 'sensor_'
      logic-delete-value: 1
      logic-not-delete-value: 0
  mapper-locations: classpath:/mapper/*.xml

spring:
  cache:
    type: simple
  application:
    name: dealAnalysis
  http:
    encoding:
      charset: UTF-8
      force: true
      enabled: true
  servlet:
    multipart:
      max-file-size: -1
      max-request-size: -1
  redis:
    host: localhost
    port: 6379
    database: 0
    sentinel:
      master: mymaster
      nodes: localhost1:26379,localhost2:26379,localhost3:26379
    timeout: 1000
    password: 123456
    lettuce:
      pool:
        max-active: 8
        max-idle: 8
        min-idle: 0
        max-wait: -1
  datasource:
    vertica:
      url: jdbc:vertica://localhost:5433/sensor
      username: dbadmin
      password: 123456
      driver-class-name: com.vertica.jdbc.Driver
      type: com.zaxxer.hikari.HikariDataSource
      hikari:
        pool-name: SensorVerticaDatasourePool
        auto-commit: true
        connection-timeout: 30000
        idle-timeout: 30000
        max-lifetime: 1800000
        minimum-idle: 4
        maximum-pool-size: 16
        connection-test-query: SELECT 1
    mysql:
      url: jdbc:mysql://localhost:3306/sensor_db?characterEncoding=utf8&useSSL=false&allowMultiQueries=true
      username: root
      password: User@123
      driver-class-name: com.mysql.cj.jdbc.Driver
      type: com.zaxxer.hikari.HikariDataSource
      hikari:
        pool-name: SensorMysqlDatasourePool
        auto-commit: true
        connection-timeout: 30000
        idle-timeout: 30000
        max-lifetime: 1800000
        minimum-idle: 4
        maximum-pool-size: 16
        connection-test-query: SELECT 1
  quartz:
    job-store-type: jdbc
    jdbc:
      initialize-schema: never
    properties:
      org:
        quartz:
          scheduler:
            instanceName: SensorQuartz
            instanceId: ${sensor.serverId}
          jobStore:
            dataSource: quartzDataSource
            class: org.quartz.impl.jdbcjobstore.JobStoreTX
            driverDelegateClass: org.quartz.impl.jdbcjobstore.StdJDBCDelegate
            tablePrefix: QRTZ_
            isClustered: true
            clusterCheckinInterval: 10000
            misfireThreshold: 3600000
            useProperties: false
            txIsolationLevelReadCommitted: true
          threadPool:
            class: org.quartz.simpl.SimpleThreadPool
            threadCount: 5
            threadPriority: 5
            makeThreadsDaemons: false
            threadsInheritGroupOfInitializingThread: true
            threadsInheritContextClassLoaderOfInitializingThread: true
EOCAT
}
