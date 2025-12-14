const User = require('../models/userModel');
const Joi = require('joi');

const userSchema = Joi.object({
  name: Joi.string().min(2).max(255).required(),
  email: Joi.string().email().required(),
  phone: Joi.string().max(50).optional()
});

const userUpdateSchema = Joi.object({
  name: Joi.string().min(2).max(255).optional(),
  email: Joi.string().email().optional(),
  phone: Joi.string().max(50).optional()
});

class UserController {
  async createUser(req, res, next) {
    try {
      const { error, value } = userSchema.validate(req.body);
      if (error) {
        return res.status(400).json({ error: error.details[0].message });
      }

      const existingUser = await User.findByEmail(value.email);
      if (existingUser) {
        return res.status(409).json({ error: 'User with this email already exists' });
      }

      const user = await User.create(value);
      console.log(`User created: ${user.id}`);
      res.status(201).json(user);
    } catch (err) {
      next(err);
    }
  }

  async getUser(req, res, next) {
    try {
      const user = await User.findById(req.params.id);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      res.json(user);
    } catch (err) {
      next(err);
    }
  }

  async getAllUsers(req, res, next) {
    try {
      const users = await User.findAll();
      res.json(users);
    } catch (err) {
      next(err);
    }
  }

  async updateUser(req, res, next) {
    try {
      const { error, value } = userUpdateSchema.validate(req.body);
      if (error) {
        return res.status(400).json({ error: error.details[0].message });
      }

      const user = await User.update(req.params.id, value);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      console.log(`User updated: ${user.id}`);
      res.json(user);
    } catch (err) {
      next(err);
    }
  }

  async deleteUser(req, res, next) {
    try {
      const user = await User.delete(req.params.id);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      console.log(`User deleted: ${req.params.id}`);
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new UserController();
