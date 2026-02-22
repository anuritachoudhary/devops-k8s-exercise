pipelineJob('insert-time-into-postgres') {
  description('Runs a dynamic K8s pod that inserts current timestamp into Postgres every 5 minutes.')
  triggers { cron('H/5 * * * *') }
  definition {
    cps {
      sandbox(true)
      script('''
        pipeline {
          agent {
            kubernetes {
              label "time-writer-agent"
              defaultContainer "writer"
              yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: time-writer
spec:
  restartPolicy: Never
  containers:
    - name: writer
      image: time-writer:1.0
      imagePullPolicy: IfNotPresent
      env:
        - name: DB_HOST
          value: "postgres-postgresql.devops.svc.cluster.local"
        - name: DB_USER
          value: "devopsuser"
        - name: DB_NAME
          value: "devopsdb"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: postgres-password
'''
            }
          }
          stages {
            stage('Write timestamp') {
              steps { sh '/app/entrypoint.sh' }
            }
          }
        }
      '''.stripIndent())
    }
  }
}

