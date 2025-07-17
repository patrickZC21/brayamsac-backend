#!/bin/bash

# ===================================
# SCRIPT DE DESPLIEGUE AWS EC2
# Sistema de Asistencias Brayamsac
# ===================================

echo "🚀 Iniciando despliegue en AWS EC2..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para logs
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Verificar Node.js
log_info "Verificando Node.js..."
if ! command -v node &> /dev/null; then
    log_error "Node.js no está instalado. Instálalo primero:"
    echo "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
    echo "sudo apt-get install -y nodejs"
    exit 1
fi

# 2. Verificar PM2 (recomendado para producción)
log_info "Verificando PM2..."
if ! command -v pm2 &> /dev/null; then
    log_warning "PM2 no encontrado. Instalando..."
    sudo npm install -g pm2
fi

# 3. Instalar dependencias
log_info "Instalando dependencias de producción..."
npm ci --only=production

# 4. Verificar variables de entorno
log_info "Verificando configuración..."
if [ ! -f ".env" ]; then
    log_warning "Archivo .env no encontrado. Copiando desde .env.ec2..."
    cp .env.ec2 .env
    log_error "⚠️  IMPORTANTE: Edita .env y configura tu IP pública de EC2"
    log_error "⚠️  Cambia: FRONTEND_URL=http://TU-IP-PUBLICA-EC2:5173"
    echo "Presiona Enter cuando hayas configurado .env"
    read
fi

# 5. Verificar conectividad a base de datos
log_info "Probando conexión a base de datos..."
node -e "
const mysql = require('mysql2/promise');
require('dotenv').config();

const testConnection = async () => {
  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME
    });
    
    await connection.query('SELECT 1');
    console.log('✅ Conexión a base de datos exitosa');
    await connection.end();
  } catch (error) {
    console.error('❌ Error de conexión:', error.message);
    process.exit(1);
  }
};

testConnection();
"

if [ $? -ne 0 ]; then
    log_error "Fallo en la conexión a base de datos. Verifica tus credenciales."
    exit 1
fi

# 6. Configurar PM2
log_info "Configurando PM2..."
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'brayamsac-backend',
    script: 'src/index.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
EOF

# 7. Crear directorio de logs
mkdir -p logs

# 8. Configurar firewall (si está habilitado)
log_info "Configurando firewall..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 3000
    sudo ufw allow 22
    log_info "Puertos 3000 y 22 abiertos en UFW"
fi

# 9. Iniciar aplicación con PM2
log_info "Iniciando aplicación con PM2..."
pm2 stop brayamsac-backend 2>/dev/null || true
pm2 delete brayamsac-backend 2>/dev/null || true
pm2 start ecosystem.config.js

# 10. Guardar configuración PM2
pm2 save
pm2 startup

# 11. Verificar que esté funcionando
sleep 5
log_info "Verificando aplicación..."
curl -f http://localhost:3000/health || {
    log_error "La aplicación no responde en el puerto 3000"
    pm2 logs brayamsac-backend --lines 20
    exit 1
}

# 12. Mostrar información final
echo ""
log_info "🎉 ¡DESPLIEGUE COMPLETADO!"
echo ""
echo "📊 Estado de la aplicación:"
pm2 status

echo ""
echo "🌐 URLs disponibles:"
echo "   Health Check: http://$(curl -s ifconfig.me):3000/health"
echo "   API Principal: http://$(curl -s ifconfig.me):3000"
echo "   Documentación: http://$(curl -s ifconfig.me):3000/api-docs"

echo ""
echo "📝 Comandos útiles:"
echo "   Ver logs: pm2 logs brayamsac-backend"
echo "   Reiniciar: pm2 restart brayamsac-backend"
echo "   Parar: pm2 stop brayamsac-backend"
echo "   Estado: pm2 status"

echo ""
log_warning "⚠️  RECORDATORIOS IMPORTANTES:"
echo "1. Configura los Security Groups en AWS para abrir puertos 3000 y 5173"
echo "2. Actualiza FRONTEND_URL en .env con tu IP pública de EC2"
echo "3. Considera configurar un dominio y SSL para producción"
echo "4. Configura backups automáticos de tu base de datos"

echo ""
log_info "🔗 IP pública de tu servidor: $(curl -s ifconfig.me)"
