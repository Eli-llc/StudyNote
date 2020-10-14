#!/bin/bash -x


###################
# common functions
###################

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
    # intial variables
    JAVA_PATH="/usr/local/java"
    JAVA_PACKAGE_URL="ftp://192.168.31.84/0.Sharplook_Release/OpenSource/jdk-8u261-linux-x64.tar.gz"
    DOCKER_PATH="/usr/local/docker"
    DOCKER_PACKAGE_URL="ftp://192.168.31.84/vision/app/docker/docker-18.09.5.tgz"
    SENSOR_PACKAGE_URL="ftp://192.168.31.84/0.Sharplook_Release/Sensor/4.1/sensor-4.1.9-20200930-91b64db5.tar.gz"
    SENSOR_INSTALL_PATH=$PWD
    JVM1=1024
    JVM2=1024

    PARAM_NUM=$#
    set -- "$@"

    test $PARAM_NUM -gt 0 && while true; do
        case "$1" in
            --java_path)
                JAVA_PATH=$2
                shift 2 ;;
            --java_package_url)
                JAVA_PACKAGE_URL=$2
                shift 2 ;;
            --docker_path)
                DOCKER_PATH=$2
                shift 2 ;;
            --docker_package_url)
                DOCKER_PACKAGE_URL=$2
                shift 2 ;;
            --sensor_package_url)
                SENSOR_PACKAGE_URL=$2
                shift 2 ;;
            --sensor_install_path)
                SENSOR_INSTALL_PATH=$2
                shift 2 ;;
            --jvm1)
                JVM1=$2
                shift 2 ;;
            --jvm2)
                JVM2=$2
                shift 2 ;;
            -h|--help)
                usage;;
            *)
                echo "Sorry, not clear what args: $1 mean. Skip!"
                warn_param=true
                break;;
        esac
    done
    test -z $warn_param || {
        echo "Some params you input not clear, please check usage!"
        echo "$0 -h|--help"
    }
}


####################
# common components
####################

install_java(){
    #############################################
    # usage:
    # install_java install_path java_package_url
    #############################################

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
    # Download package
    rm -rf $java_tar_file
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
    ##############################################
    # usage:
    # install_docker
    ##############################################
    command -v docker > /dev/null && { inform "docker application alreadly satisfied!"; return;}
    install_path=${1:-"/usr/local/docker"}
    defalut_package_url="ftp://192.168.31.84/vision/app/docker/docker-18.09.5.tgz"
    package_url=${2:-$defalut_package_url}
    docker_tar_file=${package_url##*/}
    docker_path=$install_path/docker
    # Start install docker
    mkdir -p $install_path
    # Download docker package
    rm -rf $docker_tar_file
    wget $package_url && test -e $docker_tar_file || raise_error "Download docker package failed!"
    # untar package
    tar -zxf $docker_tar_file -C $install_path
    test -d $docker_path && inform "Docker package untar successful!" || raise_error "Docker package untar error!"
    # Set environment
    echo 'export PATH=$PATH'":$docker_path" >> /etc/profile
    export PATH=$PATH:$docker_path
    command -v docker > /dev/null && inform "Docker install successfule!" || raise_error "Dcoker install failed!"
}

launch_dockerd(){
    ###############################################
    ## usage:
    ## launch_dockerd
    ###############################################
    # make sure dockerd is active
    install_path=${1:-"/usr/local/docker"}
    docker_path=$install_path/docker
    # check whether docker installed
    command -v docker > /dev/null || install_docker
    # launch dockerd
    for i in 10 20 30 ; do
        docker ps &> /dev/null && break
        mkdir -p /var/log
        nohup $docker_path/dockerd &> /var/log/docker.log &
        sleep $i
    done
    # check result
    sleep 10 # dockerd will auto exit while it encounter unexpected error
    ps aux | grep -v grep | grep dockerd && inform "Dockerd launched successful!" || raise_error "Dcokerd launched failed!"
}

install_algorithm(){
    ###############################################
    ## usage:
    ## install_algorithm
    ###############################################
    ## pyenv prepare
    # python environment image url
    pyenv_image_name="jax_pyenv_img"
    algorithm_port=8001
    pyenv_tar_url=${1:-"ftp://192.168.31.84/Deploy/sensor/python/env/jax_pyenv.tar"}
    pyenv_tar_file=${pyenv_tar_url##*/}
    # pyenv_path=$PWD
    # load pyenv image
    docker images | grep $pyenv_image_name || {
        rm -rf $pyenv_tar_file
        wget $pyenv_tar_url
        test -f $pyenv_tar_file || raise_error "pyenv image download failed!"
        docker import $pyenv_tar_file $pyenv_image_name
        docker images | grep $pyenv_image_name || raise_error "pyenv docker image load failed!"
    }
    ## install pyenv service
    pyenv_service_url=${2:-"ftp://192.168.31.84/0.Sharplook_Release/Sensor/4.1/jax-algorithm_1.0.0.tar.gz"}
    pyenv_service_file=${pyenv_service_url##*/}
    pyenv_service_path=${3:-$PWD/jax-algorithm}
    # download service file
    rm -rf $pyenv_service_file
    wget $pyenv_service_url
    test -f $pyenv_service_file || raise_error "Download pyenv service file failed!"
    # untar service file
    rm -rf $pyenv_service_path
    mkdir -p $pyenv_service_path
    tar -zxf $pyenv_service_file -C $pyenv_service_path
    test -z "ls -A `$pyenv_service_path`" && raise_error "Untar pyenv service file failed!"
    ## edit config
    setting_config_file=$pyenv_service_path/web/web/settings.py
    dbIP=${4:-"192.168.21.58"}
    dbPORT=${5:-5433}
    dbNAME=${6:-"dbadmin"}
    dbTABLE[1]=${a:-"sensor_dt_source"}
    dbTABLE[2]=${a:-"sensor_dt_result_online"}
    dbUSER=${7:-"dbadmin"}
    dbPASSWD=${8:-"123456"}
    sed -i 's/\(\"host\":\s*\).*/\1'\"$dbIP\"'/' $setting_config_file
    sed -i 's/\(\"port\":\s*\).*/\1'\"$dbPORT\"'/' $setting_config_file
    sed -i 's/\(\"database\":\s*\).*/\1'\"$dbNAME\"'/' $setting_config_file
    sed -i 's/\(\"username\":\s*\).*/\1'\"$dbUSER\"'/' $setting_config_file
    sed -i 's/\(\"password\":\s*\).*/\1'\"$dbPASSWD\"'/' $setting_config_file
    ## launch pyenv service
    pyenv_service_container_name=jax_pyenv
    cd $pyenv_service_path
    docker ps | grep $pyenv_service_container_name && docker kill $pyenv_service_container_name
    sleep 2
    docker run -p ${algorithm_port}:8020 -h ${pyenv_service_container_name} --name ${pyenv_service_container_name} -e LANG=C.UTF-8 --cpus 4 --memory 2g -v $(pwd):/jax-algorithm -v $(pwd)/web/release/uwsgi.conf:/etc/nginx/conf.d/uwsgi.conf --workdir /jax-algorithm/web -d --rm -it ${pyenv_image_name} /jax-algorithm/web/start.sh
    # check result
    sleep 2
    docker ps | grep $pyenv_service_container_name || inform "pyenv service launch successful!" || raise_error "pyenv service launch failed!"
    cd - > /dev/null
}


install_sensor(){
    ###################################
    # install sensor
    # usage:
    #   install_sensor sensor_package_url
    ###################################

    # basic variables
    sensor_package_url=${1:-"ftp://192.168.31.84/0.Sharplook_Release/Sensor/4.1/sensor-4.1.9-20200930-91b64db5.tar.gz"}
    sensor_package_file=${sensor_package_url##*/}
    sensor_install_path=${2:-$PWD}
    JVM1=${3:-1024}
    JVM2=${4:-1024}

    # download sensor package file
    wget $sensor_package_url > /dev/null
    tar -zxf $sensor_package_file -C $sensor_install_path

    ## generator config
    generator_config && {
        cp -f application.yml $sensor_install_path/sensor/application.yml
        cp -f bootstrap.properties $sensor_install_path/sensor/bootstrap.properties
        cp -f sensor.conf $sensor_install_path/sensor/sensor.conf
    }

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
    #############################
    ## generator common files
    #############################

    ## basic variables
    sensor_port=9088
    jax_server_name="jax"
    cmdb_server_name="cmdb"
    mysql_db_name="sensor_db_auto"
    mysql_addr_port="192.168.31.40:3306"
    mysql_user="root"
    mysql_passwd="MySQL@123"
    mysql_addr="jdbc:mysql://${mysql_addr_port}/${mysql_db_name}?characterEncoding=utf8&useSSL=false&allowMultiQueries=true"
    kafka_addr="192.168.31.132"
    kafka_port=9092
    kafka_part_num=3
    kafka_groupid=""
    kt_predict="kt_predict"
    kt_alert="kt_alert"
    kt_offline="kt_offline"
    kt_online="kt_online"
    kt_sync="kt_sync"
    view_addr="localhost"
    view_port=8001
    warm_up="false"
    nacos_pub="MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC9IARaXJGPLOLsVqHVCI9xLSna4EaKWU6nHEUOHFvYG9LbLMm9h6DY8XJsC/ieO4wRZcqQnUObuhm42Ss7lDf1Wvs9cUZaUlznt6+iby0ehwj/ikp67p3R7Njyg0LCxAbnJJYK98/cFuKm1h5x64iUb5gYvUL0Yr9zSFw2g+7Z8QIDAQAB"
    nacos_priv="MIICdwIBADANBgkqhkiG9w0BAQEFAASCAmEwggJdAgEAAoGBAL0gBFpckY8s4uxWodUIj3EtKdrgRopZTqccRQ4cW9gb0tssyb2HoNjxcmwL+J47jBFlypCdQ5u6GbjZKzuUN/Va+z1xRlpSXOe3r6JvLR6HCP+KSnrundHs2PKDQsLEBucklgr3z9wW4qbWHnHriJRvmBi9QvRiv3NIXDaD7tnxAgMBAAECgYEAsIyB48TEUQ7K62tX+WHbXgCWMO/qid4i0VdPk4OfrVcT+GyQC3DgE4UZlol6VmQqNld6yJM2eNo6htecRyrvLG4FwLQcWIBqJQySoyYeekKLQVsnYU4vGjvA92E8cUHfnTJ/ZSTUFLRDinzCMRvL4mHaINVQSizBTAnZpA3eqAECQQDhxQRX71uJGAP8v9bEJy5jvdidhGxYFaQLfUik4rDxkOr+4RaNSWGAcKLfPrfk6zHvXbp6UkKZsk7uMpj42WSBAkEA1nLj5m6DcUFI6lfzonrpnCvsiaQhvOOXPsMpNoNPFdBvgOeACIVCSv2QQUD0+N1fXRjz243/iDhEic7WqKb9cQJAN/rb+tnUvod/5ZnDrNtyOzUFkvkUzDqBdH/aFVhIO32NZyl0qA+751cGa4hnnJFczldVN6NR9D4sKA/PslRlAQJBAJAOw+vTB3d4TLwn8yGOAgqIMzDPUl6qYLqnrbLSCLl1uMHWQdr3ce4gYdyD/0yCoYJPtdkijar7aYdNrEPFUfECQCxkn830hLKQM9GCdEkJEI3bW6UqzoUWweExul1AD5R9E8wKvjkBSUaaTuyQQpxw/xqJBveMYWJmNiKKQxSG72A"
    redis_type="single"  # sentinel or single
    redis_addr="192.168.31.54"
    redis_port=6379
    redis_passwd="123456"
    vertica_addr="192.168.21.58"
    vertica_port="5433"
    vertica_db_name="dbadmin"
    vertica_user="dbadmin"
    vertica_passwd="123456"
    vertica_url="jdbc:vertica://${vertica_addr}:${vertica_port}/${vertica_db_name}"
    nacos_app_name="dealAnalysis"
    nacos_addr="192.168.21.58"
    nacos_port="8848"
    nacos_user="nacos"
    nacos_passwd="0192023A7BBD73250516F069DF18B500"
    nacos_ns=""  # namespace

    # generate sensor config
    cat > application.yml <<EOCAT
server:
  port: $sensor_port
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
      name: ${jax_server_name}
    timeoutSeconds: 300
  es:
    timeoutSeconds: 60
    scrollSize: 5000
  kafka:
    server: ${kafka_addr}:${kafka_port}
    timeoutSeconds: 5
  predict:
    kafkaServer: \${sensor.kafka.server}
    kafkaTopic: ${kt_predict}
  alert:
    kafkaServer: \${sensor.kafka.server}
    kafkaTopic: ${kt_alert}
  offline:
    kafkaServer: \${sensor.kafka.server}
    kafkaTopic: ${kt_offline}
  online:
    kafkaServer: \${sensor.kafka.server}
    kafkaTopic: ${kt_online}
    pipeline:
      warmUpEnabled: ${warm_up}
  sync:
    kafkaServer: \${sensor.kafka.server}
    kafkaTopic: ${kt_sync}
    health:
      intervalSecond: 60
      schema: sensor_sched
  view:
    remote:
      server: ${view_addr}:${view_port}
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
  publicKey: ${nacos_pub}
  privateKey: ${nacos_priv}
  model:
    storage:
      type: redis
  redis:
    type: ${redis_type}
  cmdb:
    serviceName: ${cmdb_server_name}
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
    host: ${redis_addr}
    port: ${redis_port}
    database: 0
    sentinel:
      master: mymaster
      nodes: localhost1:26379,localhost2:26379,localhost3:26379
    timeout: 1000
    password: ${redis_passwd}
    lettuce:
      pool:
        max-active: 8
        max-idle: 8
        min-idle: 0
        max-wait: -1
  datasource:
    vertica:
      url: ${vertica_url}
      username: ${vertica_user}
      password: ${vertica_passwd}
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
      url: ${mysql_url}
      username: ${mysql_user}
      password: ${mysql_passwd}
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
            instanceId: \${sensor.serverId}
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
    # generate bootstrap.properties for registry nacos
    cat > bootstrap.properties <<-EOCAT
        spring.application.name=${nacos_app_name}
        spring.profiles.active=dev
        spring.cloud.nacos.config.server-addr=${nacos_addr}:${nacos_port}
        spring.cloud.nacos.config.username=${nacos_user}
        spring.cloud.nacos.config.password=${nacos_passwd}
        spring.cloud.nacos.config.namespace=${nacos_ns}
        spring.cloud.nacos.config.file-extension=yaml
        spring.cloud.nacos.config.enabled=false

        spring.cloud.nacos.discovery.server-addr=${nacos_addr}:${nacos_port}
        spring.cloud.nacos.discovery.username=${nacos_user}
        spring.cloud.nacos.discovery.password=${nacos_passwd}
        spring.cloud.nacos.discovery.cluster-name=${nacos_app_name}
        spring.cloud.nacos.discovery.namespace=${nacos_ns}
EOCAT
    # generate sensor.conf
    cat > sensor.conf <<-EOCAT
        username=${vertica_user}
        password=${vertica_passwd}
        dbhost=${vertica_addr}
        dbport=${vertica_port}
        config-schema=sensor_sched
EOCAT
    # generate sensor_kafka_connector.sh
    cat > sensor_kafka_connector.sh <<-EOCAT
    #!/bin/sh
    kafkaUrl=$kafka_addr:$kafka_port
    partitionNum=$kafka_part_num
    groupid=$kafka_groupid
    vUser=$vertica_user
    vPassword=$vertica_passwd

    PATH=$PATH:/opt/vertica/packages/kafka/bin
    export PATH

    echo '创建资源池...'
    echo 'DROP RESOURCE POOL sensor_pool;' | vsql -w \$vPassword -U \$vUser
    echo "CREATE RESOURCE POOL sensor_pool MAXMEMORYSIZE '4G' PLANNEDCONCURRENCY 2 EXECUTIONPARALLELISM 2 QUEUETIMEOUT 0;" | vsql -w \$vPassword -U \$vUser

    echo '创建计划任务...'
    vkconfig scheduler --create --config-schema sensor_sched --operator dbadmin --frame-duration '00:00:30' --resource-pool sensor_pool --consumer-group-id \$groupid  --conf sensor.conf

    echo '创建kafka cluster...'
    vkconfig cluster --delete --cluster kafka_sensor --conf sensor.conf
    vkconfig cluster --create --cluster kafka_sensor  --hosts \$kafkaUrl --conf sensor.conf

    echo '创建load-spec...'
    vkconfig load-spec --create --parser KafkaJSONParser --load-spec sensor_load --conf sensor.conf

    echo '创建sensor_offline_detect加载connector...'
    vkconfig target --create --target-schema public --target-table sensor_dt_result_offline --conf sensor.conf
    vkconfig source --create --cluster kafka_sensor --source ${kt_offline} --partitions \$partitionNum --conf sensor.conf
    vkconfig microbatch --create --microbatch sensor_offline_detect --target-schema public --target-table sensor_dt_result_offline --add-source ${kt_offline} --add-source-cluster kafka_sensor --load-spec sensor_load --consumer-group-id \$groupid  --conf sensor.conf

    echo '创建sensor_online_detect加载connector...'
    vkconfig target --create --target-schema public --target-table sensor_dt_result_online --conf sensor.conf
    vkconfig source --create --cluster kafka_sensor --source ${kt_online} --partitions \$partitionNum --conf sensor.conf
    vkconfig microbatch --create --microbatch sensor_online_detect --target-schema public --target-table sensor_dt_result_online --add-source ${kt_online} --add-source-cluster kafka_sensor --load-spec sensor_load --consumer-group-id \$groupid  --conf sensor.conf

    echo '创建sensor-sync-data加载connector...'
    vkconfig target --create --target-schema public --target-table sensor_dt_source --conf sensor.conf
    vkconfig source --create --cluster kafka_sensor --source ${kt_sync} --partitions \$partitionNum --conf sensor.conf
    vkconfig microbatch --create --microbatch sensor_source --target-schema public --target-table sensor_dt_source --add-source ${kt_sync} --add-source-cluster kafka_sensor --load-spec sensor_load --consumer-group-id \$groupid  --conf sensor.conf

    echo '创建sensor-predict加载connector...'
    vkconfig target --create --target-schema public --target-table sensor_tb_capacity --conf sensor.conf
    vkconfig source --create --cluster kafka_sensor --source ${kt_predict} --partitions \$partitionNum --conf sensor.conf
    vkconfig microbatch --create --microbatch sensor_capacity --target-schema public --target-table sensor_tb_capacity --add-source ${kt_predict} --add-source-cluster kafka_sensor --load-spec sensor_load --consumer-group-id \$groupid  --conf sensor.conf

    echo '创建sensor-alert加载connector...'
    vkconfig target --create --target-schema public --target-table sensor_tb_alert --conf sensor.conf
    vkconfig source --create --cluster kafka_sensor --source ${kt_alert} --partitions \$partitionNum --conf sensor.conf
    vkconfig microbatch --create --microbatch sensor_alert --target-schema public --target-table sensor_tb_alert --add-source ${kt_alert} --add-source-cluster kafka_sensor --load-spec sensor_load --consumer-group-id \$groupid  --conf sensor.conf
    # 修改Launcher后台运行的方式,保持launch一直后台运行
    while true; do
        launch_pid=`jps | grep "Launcher" | cut -d " " -f 1`
        test -z $launch_pid && vkconfig launch --conf sensor.conf &
        sleep 60
        jps
    done
EOCAT
}


main(){
    handle_params    
    # echo -e "docker path is $DOCKER_PATH\npckage url is $DOCKER_PACKAGE_URL"
    install_java $JAVA_PATH $JAVA_PACKAGE_URL
    install_docker $DOCKER_PATH $DOCKER_PACKAGE_URL
    launch_dockerd
    install_algorithm
    # install_sensor $SENSOR_PACKAGE_URL $SENSOR_INSTALL_PATH $JVM1 $JVM2
}

main
