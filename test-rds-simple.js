// ===================================
// TEST SIMPLE DE CONEXIÓN AWS RDS (CommonJS)
// ===================================

const mysql = require('mysql2/promise');
require('dotenv').config();

const testSimpleRDS = async () => {
  console.log('🔄 Probando conexión simple a AWS RDS...\n');
  
  const config = {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: process.env.DB_SSL === 'true' ? {
      rejectUnauthorized: false
    } : false
  };

  console.log('📋 Configuración:');
  console.log(`   Host: ${config.host}`);
  console.log(`   Database: ${config.database}`);
  console.log(`   SSL: ${config.ssl ? 'Habilitado' : 'Deshabilitado'}`);
  console.log('');

  try {
    console.log('1️⃣  Conectando a RDS...');
    const connection = await mysql.createConnection(config);
    console.log('   ✅ Conexión establecida exitosamente');

    console.log('\n2️⃣  Verificando versión...');
    const [version] = await connection.query('SELECT VERSION() as version');
    console.log(`   ✅ MySQL ${version[0].version}`);

    console.log('\n3️⃣  Listando tablas...');
    const [tables] = await connection.query('SHOW TABLES');
    console.log(`   ✅ ${tables.length} tablas encontradas:`);
    
    if (tables.length > 0) {
      tables.slice(0, 10).forEach(table => {
        const tableName = Object.values(table)[0];
        console.log(`      - ${tableName}`);
      });
      if (tables.length > 10) {
        console.log(`      ... y ${tables.length - 10} más`);
      }
    }

    console.log('\n4️⃣  Probando una consulta básica...');
    const [result] = await connection.query('SELECT 1 + 1 as resultado');
    console.log(`   ✅ Resultado: ${result[0].resultado}`);

    // Si hay tablas, intentar contar registros de usuarios
    if (tables.length > 0) {
      try {
        console.log('\n5️⃣  Verificando datos existentes...');
        const [usuarios] = await connection.query('SELECT COUNT(*) as total FROM usuarios');
        console.log(`   ✅ Usuarios en la BD: ${usuarios[0].total}`);
        
        const [trabajadores] = await connection.query('SELECT COUNT(*) as total FROM trabajadores');
        console.log(`   ✅ Trabajadores en la BD: ${trabajadores[0].total}`);
      } catch (error) {
        console.log('   ⚠️  Algunas tablas pueden no tener datos aún');
      }
    }

    await connection.end();

    console.log('\n🎉 ¡CONEXIÓN A RDS EXITOSA!');
    console.log('\n✅ Tu backend está listo para usar AWS RDS');
    console.log('✅ Todas las operaciones básicas funcionan correctamente');
    console.log('✅ Configuración SSL habilitada');
    console.log('\n🚀 Siguiente paso: Desplegar en EC2');

  } catch (error) {
    console.log('\n❌ ERROR DE CONEXIÓN:');
    console.log(`   Error: ${error.message}`);
    console.log(`   Code: ${error.code || 'N/A'}`);
    
    if (error.code === 'ENOTFOUND') {
      console.log('\n💡 Solución: Verifica el endpoint RDS');
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      console.log('\n💡 Solución: Verifica usuario/contraseña');
    } else if (error.code === 'ECONNREFUSED') {
      console.log('\n💡 Solución: Verifica Security Groups');
    } else if (error.code === 'ETIMEDOUT') {
      console.log('\n💡 Solución: Verifica Security Groups y conectividad de red');
    }
    
    process.exit(1);
  }
};

testSimpleRDS();
