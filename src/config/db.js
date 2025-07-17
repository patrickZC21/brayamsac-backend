import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

// Para ES Modules, obtenemos la ruta actual
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Cargar variables de entorno desde la ruta correcta (subimos 2 directorios)
const envPath = path.join(__dirname, '..', '..', '.env');
dotenv.config({ path: envPath });

// ⚡ CONFIGURACIÓN OPTIMIZADA PARA AWS RDS
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: process.env.NODE_ENV === 'production' ? 20 : 5, // Más conexiones para RDS
  queueLimit: 0,
  charset: 'utf8mb4',
  
  // 🔒 SSL HABILITADO para AWS RDS (recomendado)
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false // RDS certificates are trusted
  } : false,
  
  // ⏱️ Timeouts optimizados para RDS
  acquireTimeout: 60000,
  timeout: 60000,
  reconnect: true,
  
  // 🌐 Configuración específica para AWS RDS
  multipleStatements: false, // Seguridad
  dateStrings: true, // Mejor manejo de fechas
  supportBigNumbers: true,
  bigNumberStrings: true,
  
  // 🔄 Configuración para reconexión automática en RDS
  pool: {
    min: 2,
    max: process.env.NODE_ENV === 'production' ? 20 : 5,
    idleTimeoutMillis: 30000,
    createTimeoutMillis: 3000,
    acquireTimeoutMillis: 60000
  }
});

// Test de conexión silencioso (solo errores)
if (process.env.NODE_ENV !== 'production') {
  pool.getConnection()
    .then(connection => {
      console.log('✅ BD conectada');
      connection.release();
    })
    .catch(err => {
      console.error('❌ Error BD:', err.message);
    });
}

export default pool;


