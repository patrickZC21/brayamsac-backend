// src/index.js

// 📦 Dependencias principales
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

// ⚙️ Configuración
import pool from './config/db.js';
import { specs, swaggerUi } from './config/swagger.js';
dotenv.config(); // Cargar variables de entorno

// 🧩 Middlewares
import { manejarErrores } from './middlewares/error.middleware.js';
import { helmetConfig, apiLimiter } from './middlewares/security.middleware.js';
import { sanitizarInput } from './middlewares/validation.middleware.js';

// 🚦 Rutas
import authRoutes from './routes/auth.routes.js';
import usuariosRoutes from './routes/usuarios.routes.js';
import trabajadoresRoutes from './routes/trabajadores.routes.js';
import asistenciasRoutes from './routes/asistencias.routes.js';
import fechasRoutes from './routes/fechas.routes.js';
import almacenesRoutes from './routes/almacenes.routes.js';
import subalmacenesRoutes from './routes/subalmacenes.routes.js';
import rolesRoutes from './routes/roles.routes.js';
import dashboardRoutes from './routes/dashboard.routes.js';
import exportRoutes from './routes/export.routes.js';
import usuarioAlmacenesRoutes from './routes/usuarioAlmacenes.routes.js';
import trabajadorAsistenciaRoutes from './routes/trabajadorAsistencia.routes.js';
import rotacionRoutes from './routes/rotacion.routes.js';
import notificationsRoutes from './routes/notifications.routes.js';
const app = express();

// 🛡️ Middlewares de seguridad
app.use(helmetConfig); // Headers de seguridad
app.use(apiLimiter); // Rate limiting general
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? [process.env.FRONTEND_URL || 'https://tu-dominio-frontend.com']
    : [
        'http://localhost:5173',
        'http://localhost:5174', 
        'http://localhost:5175',
        'http://localhost:3000'
      ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '10mb' })); // Limitar tamaño del body
app.use(sanitizarInput); // Sanitización de input

// 🧪 Ruta de prueba del servidor
app.get('/', (req, res) => {
  res.send('Servidor backend funcionando. Usa /ping-db para probar la conexión a la base de datos.');
});

// 📖 Documentación API con Swagger
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Brayamsac API Documentation',
  customfavIcon: '/favicon.ico'
}));

// 🧪 Verificación conexión BD
app.get('/ping-db', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT NOW() AS time');
    res.json({ connected: true, time: rows[0].time });
  } catch (err) {
    console.error('❌ Error de conexión:', err.message);
    res.status(500).json({ connected: false, error: err.message });
  }
});

// 🏥 Health check robusto para AWS Load Balancer
app.get('/health', async (req, res) => {
  try {
    // Test database connectivity
    await pool.query('SELECT 1');
    
    const healthCheck = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
      database: 'connected',
      memory: {
        used: Math.round((process.memoryUsage().heapUsed / 1024 / 1024) * 100) / 100,
        total: Math.round((process.memoryUsage().heapTotal / 1024 / 1024) * 100) / 100
      }
    };
    
    res.status(200).json(healthCheck);
  } catch (error) {
    const healthCheck = {
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
      database: 'disconnected'
    };
    
    res.status(503).json(healthCheck);
  }
});

// 🔗 Rutas API
app.use('/api/auth', authRoutes);
app.use('/api/usuarios', usuariosRoutes);
app.use('/api/trabajadores', trabajadoresRoutes);
app.use('/api/asistencias', asistenciasRoutes);
app.use('/api/fechas', fechasRoutes);
app.use('/api/almacenes', almacenesRoutes);
app.use('/api/subalmacenes', subalmacenesRoutes);
app.use('/api/roles', rolesRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/exportar', exportRoutes);
app.use('/api/usuario-almacenes', usuarioAlmacenesRoutes);
// GET /api/trabajadores/:id/asistencias-personales
app.use('/api/trabajadorAsistencia', trabajadorAsistenciaRoutes);
app.use('/api/rotaciones', rotacionRoutes);
app.use('/api/notifications', notificationsRoutes);
// 🚨 Middleware de errores (siempre al final)
app.use(manejarErrores);

// 🚀 Arrancar servidor
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Servidor en puerto ${PORT} | Modo: ${process.env.NODE_ENV || 'development'}`);
});
