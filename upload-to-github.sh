#!/bin/bash

# ===================================
# SCRIPT PARA SUBIR BACKEND A GITHUB
# ===================================

echo "🚀 Preparando backend para GitHub..."

# Ir al directorio Backend
cd Backend

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ]; then
    echo "❌ Error: No se encontró package.json. Verifica que estés en el directorio Backend"
    exit 1
fi

# Eliminar .env del repositorio si ya fue añadido (por seguridad)
git rm --cached .env 2>/dev/null || true

# Inicializar repositorio si no existe
if [ ! -d ".git" ]; then
    git init
fi

# Agregar archivos (excepto .env por .gitignore)
git add .

# Commit
git commit -m "Backend: Sistema de Asistencias Brayamsac con AWS RDS"

# Configurar rama main
git branch -M main

# Agregar origin si no existe
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/patrickZC21/brayamsac-backend.git

echo "📋 Para completar, ejecuta:"
echo "git push -u origin main"
echo ""
echo "⚠️  Si falla la autenticación, necesitas:"
echo "1. Crear Personal Access Token en GitHub"
echo "2. Usar: git push https://TU_TOKEN@github.com/patrickZC21/brayamsac-backend.git main"
