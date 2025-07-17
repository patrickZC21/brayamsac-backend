module.exports = {
  apps: [{
    name: 'brayamsac-backend',
    script: 'src/index.js',
    instances: 1, // Puedes aumentar según tu instancia EC2
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    // Logging
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    
    // Rotación de logs
    log_date_format: 'YYYY-MM-DD HH:mm Z',
    merge_logs: true,
    
    // Reinicio automático en caso de errores
    min_uptime: '10s',
    max_restarts: 10,
    
    // Variables de entorno específicas
    node_args: '--max-old-space-size=1024'
  }]
};
