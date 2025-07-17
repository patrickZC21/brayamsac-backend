#!/bin/bash

# ===================================
# DESPLIEGUE EN EC2 DESDE GITHUB
# Sistema de Asistencias Brayamsac
# ===================================

echo "🚀 Iniciando despliegue desde GitHub en EC2..."

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. ACTUALIZAR SISTEMA
log_info "Actualizando sistema Ubuntu..."
sudo apt update && sudo apt upgrade -y

# 2. INSTALAR NODE.JS 18 (PRIMERO)
log_info "Instalando Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 3. VERIFICAR NODE.JS
log_info "Verificando Node.js..."
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# 4. INSTALAR PM2
log_info "Instalando PM2..."
sudo npm install -g pm2

# 5. VERIFICAR/INSTALAR GIT
log_info "Verificando Git..."
if ! command -v git &> /dev/null; then
    log_info "Instalando Git..."
    sudo apt install -y git
fi
echo "Git version: $(git --version)"

# 6. VERIFICAR INSTALACIONES FINALES
log_info "Verificando todas las instalaciones..."
echo "✅ Node.js: $(node --version)"
echo "✅ NPM: $(npm --version)"
echo "✅ PM2: $(pm2 --version)"
echo "✅ Git: $(git --version)"

# 7. CLONAR REPOSITORIO
log_info "Clonando repositorio desde GitHub..."
cd ~
rm -rf brayamsac-backend 2>/dev/null || true
git clone https://github.com/patrickZC21/brayamsac-backend.git
cd brayamsac-backend

# 8. INSTALAR DEPENDENCIAS
log_info "Instalando dependencias de producción..."
npm ci --only=production

# 9. CONFIGURAR VARIABLES DE ENTORNO
log_info "Configurando variables de entorno..."

# IP pública de la instancia EC2
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
log_info "IP pública detectada: $PUBLIC_IP"

# Crear archivo .env
cat > .env << EOF
# ===================================
# AWS EC2 PRODUCTION CONFIG
# ===================================

# Base de datos AWS RDS
DB_HOST=database-1-brayam-sac.cd6ygkkwilu7.sa-east-1.rds.amazonaws.com
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=7_v28I4kmc
DB_NAME=brayamsacasistencia_control_asistencias
DB_SSL=true

# JWT y servidor
JWT_SECRET=469153bbbce98a888cec341bb2f67c76cf3b1b13112426c63af0b23a849e4018abc123def456
NODE_ENV=production
PORT=3000

# Frontend URL con IP pública de EC2
FRONTEND_URL=http://$PUBLIC_IP:5173

# Sesión
SESSION_SECRET=brayamsac_ec2_session_secret_2025
EOF

log_info "Archivo .env creado con IP: $PUBLIC_IP"

# 10. PROBAR CONEXIÓN A RDS
log_info "Probando conexión a base de datos RDS..."
if node test-rds-simple.cjs; then
    log_info "✅ Conexión a RDS exitosa"
else
    log_error "❌ Error de conexión a RDS"
    log_error "Verifica Security Groups de RDS"
    exit 1
fi

# 11. CONFIGURAR PM2
log_info "Configurando PM2..."
pm2 stop brayamsac-backend 2>/dev/null || true
pm2 delete brayamsac-backend 2>/dev/null || true
pm2 start ecosystem.config.js

# 12. CONFIGURAR PM2 PARA AUTOSTART
pm2 save
pm2 startup | tail -n 1 > pm2_startup.sh
chmod +x pm2_startup.sh
sudo ./pm2_startup.sh

# 13. CONFIGURAR FIREWALL
log_info "Configurando firewall Ubuntu..."
sudo ufw allow 22      # SSH
sudo ufw allow 3000    # Backend API
sudo ufw allow 5173    # Frontend
sudo ufw allow 80      # HTTP
sudo ufw allow 443     # HTTPS
sudo ufw --force enable

# 14. CREAR DIRECTORIO DE LOGS
mkdir -p logs

# 15. VERIFICAR DESPLIEGUE
log_info "Verificando despliegue..."
sleep 5

if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    log_info "✅ Backend funcionando correctamente"
else
    log_error "❌ Backend no responde"
    pm2 logs brayamsac-backend --lines 20
    exit 1
fi

# 16. MOSTRAR INFORMACIÓN FINAL
echo ""
echo "🎉 ¡DESPLIEGUE COMPLETADO EXITOSAMENTE!"
echo ""
log_info "📊 Estado de la aplicación:"
pm2 status

echo ""
log_info "🌐 URLs disponibles:"
echo "   ✅ Health Check: http://$PUBLIC_IP:3000/health"
echo "   ✅ API Principal: http://$PUBLIC_IP:3000"
echo "   ✅ Documentación: http://$PUBLIC_IP:3000/api-docs"

echo ""
log_info "📝 Comandos útiles:"
echo "   Ver logs: pm2 logs brayamsac-backend"
echo "   Reiniciar: pm2 restart brayamsac-backend"
echo "   Parar: pm2 stop brayamsac-backend"
echo "   Estado: pm2 status"

echo ""
log_warning "📋 NEXT STEPS:"
echo "1. ✅ Verificar que los Security Groups permiten tráfico en puertos 3000 y 5173"
echo "2. ✅ Probar la API desde tu navegador: http://$PUBLIC_IP:3000/health"
echo "3. ✅ Configurar tu frontend para usar: http://$PUBLIC_IP:3000 como API_URL"
echo "4. 🔒 Considera configurar un dominio y SSL para producción"

echo ""
log_info "🎯 Tu backend está listo en: http://$PUBLIC_IP:3000"
