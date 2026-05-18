# MobileShop Admin Web Application

Admin dashboard for Mobile Ecommerce platform built with React + Vite + Tailwind CSS.

## Features

- ✅ Modern, responsive login interface
- ✅ Theme system with OKLCH colors
- ✅ API integration with backend
- ✅ Error handling and loading states
- ✅ Tailwind CSS for styling

## Prerequisites

- Node.js 18+ 
- npm or yarn

## Installation

```bash
# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Edit .env if backend is on different URL
```

## Development

```bash
# Start development server
npm run dev

# Opens at http://localhost:5173
```

## Build

```bash
# Build for production
npm run build

# Preview production build
npm run preview
```

## API Integration

The app is configured to connect to the backend API at `http://localhost:5000/v1/api` by default.

### Environment Variables

- `VITE_API_URL` - Backend API base URL (default: `http://localhost:5000/v1/api`)

### API Endpoints Used

- `POST /auth/login` - User login
- `POST /auth/register` - User registration  
- `POST /auth/verify-otp` - OTP verification

## Project Structure

```
src/
├── components/
│   ├── ui/
│   │   ├── button.jsx
│   │   ├── input.jsx
│   │   ├── label.jsx
│   │   └── checkbox.jsx
│   └── login-form.jsx
├── api/
│   └── client.js          # Axios client with interceptors
├── App.jsx
├── main.jsx
└── index.css              # Tailwind styles
```

## Technologies

- **React 19** - UI library
- **Vite** - Build tool
- **Tailwind CSS 4** - Styling
- **Axios** - HTTP client
- **Lucide React** - Icons

## License

© 2024 MobileShop Admin. All rights reserved.
