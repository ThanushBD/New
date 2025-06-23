const express = require('express');
const { 
  register, 
  login, 
  googleAuth, 
  forgotPassword, 
  resetPassword, 
  verifyEmail, 
  getProfile 
} = require('../controllers/authController');
const { authenticateToken } = require('../middleware/auth');
const { validateRegister, validateLogin, validateForgotPassword, validateResetPassword } = require('../middleware/validation');

const router = express.Router();

router.post('/register', validateRegister, register);
router.post('/login', validateLogin, login);
router.post('/google', googleAuth);
router.post('/forgot-password', validateForgotPassword, forgotPassword);
router.post('/reset-password', validateResetPassword, resetPassword);
router.get('/verify-email', verifyEmail);
router.get('/profile', authenticateToken, getProfile);

module.exports = router;