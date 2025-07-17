#!/bin/bash

# ===================================
# MIGRACIÓN DE BASE DE DATOS A AWS RDS
# Sistema de Asistencias Brayamsac
# ===================================

echo "🔄 Iniciando migración de base de datos a AWS RDS..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# ===================================
# PASO 1: EXPORTAR DATOS ACTUALES
# ===================================

log_step "1. Exportando datos de AlwaysData..."

# Configuración de la BD actual (AlwaysData)
OLD_HOST="mysql-brayamsacasistencia.alwaysdata.net"
OLD_USER="417526_brayamsac"
OLD_PASSWORD="MZAE1vmKIBsq3elT7vUefwjL6cXKR6"
OLD_DATABASE="brayamsacasistencia_control_asistencias"

# Crear backup de la BD actual
log_info "Creando backup de base de datos actual..."
mysqldump -h $OLD_HOST -u $OLD_USER -p$OLD_PASSWORD $OLD_DATABASE > backup_alwaysdata_$(date +%Y%m%d_%H%M%S).sql

if [ $? -eq 0 ]; then
    log_info "✅ Backup creado exitosamente"
else
    log_error "❌ Error al crear backup"
    exit 1
fi

# ===================================
# PASO 2: CONFIGURAR RDS
# ===================================

log_step "2. Configurando conexión a AWS RDS..."

echo "Por favor, proporciona los datos de tu instancia RDS:"
echo ""
read -p "🔗 RDS Endpoint (ej: mydb.abc123.us-east-1.rds.amazonaws.com): " RDS_HOST
read -p "👤 Usuario RDS (ej: admin): " RDS_USER
read -s -p "🔐 Contraseña RDS: " RDS_PASSWORD
echo ""
read -p "📊 Nombre de la base de datos (ej: brayamsac_asistencias): " RDS_DATABASE

# ===================================
# PASO 3: PROBAR CONEXIÓN RDS
# ===================================

log_step "3. Probando conexión a RDS..."

mysql -h $RDS_HOST -u $RDS_USER -p$RDS_PASSWORD -e "SELECT 1;" 2>/dev/null
if [ $? -eq 0 ]; then
    log_info "✅ Conexión a RDS exitosa"
else
    log_error "❌ No se puede conectar a RDS. Verifica los datos."
    exit 1
fi

# ===================================
# PASO 4: CREAR BASE DE DATOS EN RDS
# ===================================

log_step "4. Creando base de datos en RDS..."

mysql -h $RDS_HOST -u $RDS_USER -p$RDS_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $RDS_DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

if [ $? -eq 0 ]; then
    log_info "✅ Base de datos creada en RDS"
else
    log_error "❌ Error al crear base de datos en RDS"
    exit 1
fi

# ===================================
# PASO 5: IMPORTAR DATOS A RDS
# ===================================

log_step "5. Importando datos a RDS..."

# Encontrar el archivo de backup más reciente
BACKUP_FILE=$(ls -t backup_alwaysdata_*.sql | head -n1)

log_info "Importando $BACKUP_FILE a RDS..."
mysql -h $RDS_HOST -u $RDS_USER -p$RDS_PASSWORD $RDS_DATABASE < $BACKUP_FILE

if [ $? -eq 0 ]; then
    log_info "✅ Datos importados exitosamente a RDS"
else
    log_error "❌ Error al importar datos a RDS"
    exit 1
fi

# ===================================
# PASO 6: ACTUALIZAR CONFIGURACIÓN
# ===================================

log_step "6. Actualizando configuración del backend..."

# Crear nuevo archivo .env con datos de RDS
cat > .env << EOF
# ===================================
# AWS RDS CONFIGURATION - PRODUCCIÓN
# ===================================

# Base de datos AWS RDS
DB_HOST=$RDS_HOST
DB_PORT=3306
DB_USER=$RDS_USER
DB_PASSWORD=$RDS_PASSWORD
DB_NAME=$RDS_DATABASE

# SSL para RDS (recomendado en producción)
DB_SSL=true

# JWT (mantener el actual)
JWT_SECRET=469153bbbce98a888cec341bb2f67c76cf3b1b13112426c63af0b23a849e4018abc123def456
NODE_ENV=production
PORT=3000

# CAMBIAR por tu dominio de EC2 o IP pública
FRONTEND_URL=http://tu-ip-publica-ec2:5173
EOF

log_info "✅ Archivo .env actualizado con configuración RDS"

# ===================================
# PASO 7: VERIFICAR MIGRACIÓN
# ===================================

log_step "7. Verificando migración..."

# Probar conexión con Node.js
node -e "
const mysql = require('mysql2/promise');
require('dotenv').config();

const testRDSConnection = async () => {
  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      ssl: { rejectUnauthorized: false }
    });
    
    // Verificar que las tablas existen
    const [tables] = await connection.query('SHOW TABLES');
    console.log('✅ Tablas encontradas en RDS:', tables.length);
    
    // Verificar algunos datos
    const [users] = await connection.query('SELECT COUNT(*) as count FROM usuarios');
    console.log('✅ Usuarios migrados:', users[0].count);
    
    await connection.end();
    console.log('✅ Migración verificada exitosamente');
  } catch (error) {
    console.error('❌ Error de verificación:', error.message);
    process.exit(1);
  }
};

testRDSConnection();
"

if [ $? -eq 0 ]; then
    log_info "✅ Verificación de migración exitosa"
else
    log_error "❌ Error en la verificación"
    exit 1
fi

# ===================================
# RESUMEN FINAL
# ===================================

echo ""
echo "🎉 ¡MIGRACIÓN A RDS COMPLETADA!"
echo ""
log_info "📊 Resumen de la migración:"
echo "   • BD Origen: AlwaysData ($OLD_HOST)"
echo "   • BD Destino: AWS RDS ($RDS_HOST)"
echo "   • Backup creado: $BACKUP_FILE"
echo "   • Configuración actualizada: .env"
echo ""
log_warning "📋 SIGUIENTES PASOS:"
echo "1. Verificar que tu EC2 tenga acceso al Security Group de RDS"
echo "2. Asegúrate de que RDS esté en la misma VPC que EC2 (recomendado)"
echo "3. Considera configurar backup automático en RDS"
echo "4. Probar el backend con: npm start"
echo ""
log_info "🔗 Tu nueva configuración RDS:"
echo "   Host: $RDS_HOST"
echo "   Database: $RDS_DATABASE"
echo "   SSL: Habilitado"
echo ""
log_warning "🔒 IMPORTANTE: Configura los Security Groups de RDS para permitir conexiones desde tu EC2"

echo ""
echo "🚀 ¡Listo para desplegar en EC2!"
