const express = require('express');
const { body, validationResult } = require('express-validator');
const { PrismaClient } = require('@prisma/client');
const auth = require('../middleware/auth');

const router = express.Router();
const prisma = new PrismaClient();

// Validation rules
const bookValidation = [
  body('title')
    .trim()
    .isLength({ min: 1, max: 200 })
    .withMessage('Title is required and must be less than 200 characters'),
  body('author')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Author is required and must be less than 100 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 1000 })
    .withMessage('Description must be less than 1000 characters')
];

// Get all books (public)
router.get('/public', async (req, res) => {
  try {
    const { page = 1, limit = 20, search } = req.query;
    const skip = (page - 1) * limit;

    const where = search ? {
      OR: [
        { title: { contains: search, mode: 'insensitive' } },
        { author: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } }
      ]
    } : {};

    const books = await prisma.book.findMany({
      where,
      include: {
        user: {
          select: {
            name: true
          }
        }
      },
      orderBy: {
        createdAt: 'desc'
      },
      skip: parseInt(skip),
      take: parseInt(limit)
    });

    const total = await prisma.book.count({ where });

    res.json({
      books,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get public books error:', error);
    res.status(500).json({ message: 'Server error fetching books' });
  }
});

// Get user's books
router.get('/my-books', auth, async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const books = await prisma.book.findMany({
      where: {
        userId: req.user.id
      },
      orderBy: {
        createdAt: 'desc'
      },
      skip: parseInt(skip),
      take: parseInt(limit)
    });

    const total = await prisma.book.count({
      where: { userId: req.user.id }
    });

    res.json({
      books,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get user books error:', error);
    res.status(500).json({ message: 'Server error fetching your books' });
  }
});

// Create book
router.post('/', auth, bookValidation, async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { title, author, description } = req.body;

    const book = await prisma.book.create({
      data: {
        title,
        author,
        description: description || null,
        userId: req.user.id
      }
    });

    res.status(201).json(book);
  } catch (error) {
    console.error('Create book error:', error);
    res.status(500).json({ message: 'Server error creating book' });
  }
});

// Update book
router.put('/:id', auth, bookValidation, async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: errors.array() 
      });
    }

    const { id } = req.params;
    const { title, author, description } = req.body;

    // Check if book exists and belongs to user
    const existingBook = await prisma.book.findFirst({
      where: {
        id,
        userId: req.user.id
      }
    });

    if (!existingBook) {
      return res.status(404).json({ message: 'Book not found or you do not have permission to edit it' });
    }

    const book = await prisma.book.update({
      where: { id },
      data: {
        title,
        author,
        description: description || null
      }
    });

    res.json(book);
  } catch (error) {
    console.error('Update book error:', error);
    res.status(500).json({ message: 'Server error updating book' });
  }
});

// Delete book
router.delete('/:id', auth, async (req, res) => {
  try {
    const { id } = req.params;

    // Check if book exists and belongs to user
    const existingBook = await prisma.book.findFirst({
      where: {
        id,
        userId: req.user.id
      }
    });

    if (!existingBook) {
      return res.status(404).json({ message: 'Book not found or you do not have permission to delete it' });
    }

    await prisma.book.delete({
      where: { id }
    });

    res.json({ message: 'Book deleted successfully' });
  } catch (error) {
    console.error('Delete book error:', error);
    res.status(500).json({ message: 'Server error deleting book' });
  }
});

module.exports = router;
