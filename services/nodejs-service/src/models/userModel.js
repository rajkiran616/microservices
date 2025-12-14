const { pool } = require('../config/database');

class User {
  static async create(userData) {
    const { name, email, phone } = userData;
    const query = `INSERT INTO users (name, email, phone) VALUES ($1, $2, $3) RETURNING *`;
    const result = await pool.query(query, [name, email, phone]);
    return result.rows[0];
  }

  static async findById(id) {
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
    return result.rows[0];
  }

  static async findByEmail(email) {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    return result.rows[0];
  }

  static async findAll() {
    const result = await pool.query('SELECT * FROM users ORDER BY created_at DESC');
    return result.rows;
  }

  static async update(id, userData) {
    const { name, email, phone } = userData;
    const query = `
      UPDATE users 
      SET name = COALESCE($1, name), email = COALESCE($2, email), 
          phone = COALESCE($3, phone), updated_at = CURRENT_TIMESTAMP
      WHERE id = $4 RETURNING *
    `;
    const result = await pool.query(query, [name, email, phone, id]);
    return result.rows[0];
  }

  static async delete(id) {
    const result = await pool.query('DELETE FROM users WHERE id = $1 RETURNING *', [id]);
    return result.rows[0];
  }
}

module.exports = User;
