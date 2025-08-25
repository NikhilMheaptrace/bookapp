import React from 'react';
import { Link } from 'react-router-dom';
import { BookOpen, Plus, Search, TrendingUp, Users, Calendar } from 'lucide-react';

export default function DashboardPage() {
  const stats = [
    { label: 'Total Books', value: '1,234', icon: BookOpen, color: 'bg-blue-500' },
    { label: 'Books Read', value: '89', icon: TrendingUp, color: 'bg-green-500' },
    { label: 'Active Readers', value: '156', icon: Users, color: 'bg-purple-500' },
    { label: 'This Month', value: '23', icon: Calendar, color: 'bg-orange-500' },
  ];

  const recentBooks = [
    { title: 'The Great Gatsby', author: 'F. Scott Fitzgerald', status: 'Reading', progress: 65 },
    { title: '1984', author: 'George Orwell', status: 'Completed', progress: 100 },
    { title: 'To Kill a Mockingbird', author: 'Harper Lee', status: 'Wishlist', progress: 0 },
    { title: 'Pride and Prejudice', author: 'Jane Austen', status: 'Reading', progress: 32 },
  ];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      {/* Navigation */}
      <nav className="bg-white dark:bg-gray-800 shadow-sm border-b border-gray-200 dark:border-gray-700">
        <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center space-x-2">
              <BookOpen className="h-8 w-8 text-blue-600" />
              <span className="text-xl font-bold text-gray-900 dark:text-white">BookHub</span>
            </div>
            
            <div className="flex items-center space-x-4">
              <Link 
                to="/books"
                className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white transition-colors"
              >
                Books
              </Link>
              <Link 
                to="/"
                className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white transition-colors"
              >
                Logout
              </Link>
            </div>
          </div>
        </div>
      </nav>

      <div className="container mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Dashboard</h1>
          <p className="text-gray-600 dark:text-gray-400">Welcome back! Here's your reading overview.</p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          {stats.map((stat, index) => {
            const IconComponent = stat.icon;
            return (
              <div key={index} className="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-6">
                <div className="flex items-center">
                  <div className={`${stat.color} p-3 rounded-lg`}>
                    <IconComponent className="h-6 w-6 text-white" />
                  </div>
                  <div className="ml-4">
                    <p className="text-sm font-medium text-gray-600 dark:text-gray-400">{stat.label}</p>
                    <p className="text-2xl font-bold text-gray-900 dark:text-white">{stat.value}</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Recent Books */}
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-sm">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-semibold text-gray-900 dark:text-white">Recent Books</h2>
                <Link 
                  to="/books"
                  className="text-blue-600 hover:text-blue-700 text-sm font-medium"
                >
                  View All
                </Link>
              </div>
            </div>
            <div className="p-6">
              <div className="space-y-4">
                {recentBooks.map((book, index) => (
                  <div key={index} className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
                    <div className="flex-1">
                      <h3 className="font-medium text-gray-900 dark:text-white">{book.title}</h3>
                      <p className="text-sm text-gray-600 dark:text-gray-400">{book.author}</p>
                      <div className="flex items-center mt-2">
                        <span className={`px-2 py-1 text-xs rounded-full ${
                          book.status === 'Completed' ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' :
                          book.status === 'Reading' ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200' :
                          'bg-gray-100 text-gray-800 dark:bg-gray-600 dark:text-gray-200'
                        }`}>
                          {book.status}
                        </span>
                        {book.progress > 0 && (
                          <span className="ml-2 text-xs text-gray-600 dark:text-gray-400">
                            {book.progress}% complete
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-sm">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h2 className="text-lg font-semibold text-gray-900 dark:text-white">Quick Actions</h2>
            </div>
            <div className="p-6">
              <div className="space-y-4">
                <Link 
                  to="/books"
                  className="flex items-center p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg hover:bg-blue-100 dark:hover:bg-blue-900/30 transition-colors"
                >
                  <Plus className="h-6 w-6 text-blue-600 dark:text-blue-400" />
                  <div className="ml-3">
                    <h3 className="font-medium text-gray-900 dark:text-white">Add New Book</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Add a book to your collection</p>
                  </div>
                </Link>
                
                <Link 
                  to="/books"
                  className="flex items-center p-4 bg-green-50 dark:bg-green-900/20 rounded-lg hover:bg-green-100 dark:hover:bg-green-900/30 transition-colors"
                >
                  <Search className="h-6 w-6 text-green-600 dark:text-green-400" />
                  <div className="ml-3">
                    <h3 className="font-medium text-gray-900 dark:text-white">Browse Books</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400">Explore your book library</p>
                  </div>
                </Link>
                
                <div className="flex items-center p-4 bg-purple-50 dark:bg-purple-900/20 rounded-lg">
                  <TrendingUp className="h-6 w-6 text-purple-600 dark:text-purple-400" />
                  <div className="ml-3">
                    <h3 className="font-medium text-gray-900 dark:text-white">Reading Stats</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400">View your reading progress</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}