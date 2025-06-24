const pool = require('../config/database');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

class User {
  static async create({ email, password, firstName, lastName, isGoogleUser = false, googleId = null, avatarUrl = null }) {
    const hashedPassword = password ? await bcrypt.hash(password, 12) : null;
    const verificationToken = crypto.randomBytes(32).toString('hex');
    
    const query = `
      INSERT INTO users (email, password, first_name, last_name, verification_token, google_id, avatar_url, email_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING id, email, first_name, last_name, email_verified, avatar_url, created_at
    `;
    const values = [email, hashedPassword, firstName, lastName, verificationToken, googleId, avatarUrl, isGoogleUser];
    const result = await pool.query(query, values);
    return { ...result.rows[0], verificationToken };
  }

  static async findByEmail(email) {
    const query = 'SELECT * FROM users WHERE email = $1';
    const result = await pool.query(query, [email]);
    return result.rows[0];
  }

  static async findByGoogleId(googleId) {
    const query = 'SELECT * FROM users WHERE google_id = $1';
    const result = await pool.query(query, [googleId]);
    return result.rows[0];
  }

  static async findById(id) {
    const query = 'SELECT id, email, first_name, last_name, email_verified, avatar_url, created_at FROM users WHERE id = $1';
    const result = await pool.query(query, [id]);
    return result.rows[0];
  }

  static async verifyEmail(token) {
    const query = `
      UPDATE users 
      SET email_verified = true, verification_token = null 
      WHERE verification_token = $1 
      RETURNING id, email, first_name, last_name
    `;
    const result = await pool.query(query, [token]);
    return result.rows[0];
  }

  static async setResetToken(email) {
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetTokenExpires = new Date(Date.now() + 3600000); // 1 hour

    const query = `
      UPDATE users 
      SET reset_token = $1, reset_token_expires = $2 
      WHERE email = $3 
      RETURNING first_name
    `;
    const result = await pool.query(query, [resetToken, resetTokenExpires, email]);
    return { resetToken, user: result.rows[0] };
  }

  static async resetPassword(token, newPassword) {
    const hashedPassword = await bcrypt.hash(newPassword, 12);
    const query = `
      UPDATE users 
      SET password = $1, reset_token = null, reset_token_expires = null 
      WHERE reset_token = $2 AND reset_token_expires > NOW() 
      RETURNING id, email, first_name, last_name
    `;
    const result = await pool.query(query, [hashedPassword, token]);
    return result.rows[0];
  }

  static async comparePassword(plainPassword, hashedPassword) {
    return await bcrypt.compare(plainPassword, hashedPassword);
  }

  static async setEmailVerified(userId) {
    const query = 'UPDATE users SET email_verified = true WHERE id = $1';
    await pool.query(query, [userId]);
  }
}

module.exports = User;