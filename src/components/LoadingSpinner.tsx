import React from 'react'

interface LoadingSpinnerProps {
  message?: string
  className?: string
}

const LoadingSpinner: React.FC<LoadingSpinnerProps> = ({ 
  message = "Loading...", 
  className = "" 
}) => {
  return (
    <div className={`min-h-screen flex items-center justify-center relative ${className}`}>
      <div className="text-center z-10">
        {/* Main spinner with pulsing effect */}
        <div className="relative mb-6">
          <div className="animate-spin rounded-full h-16 w-16 border-4 border-primary/20 border-t-primary mx-auto"></div>
          <div className="absolute inset-0 animate-ping rounded-full h-16 w-16 border-2 border-primary/40 mx-auto"></div>
          <div className="absolute inset-2 animate-pulse rounded-full h-12 w-12 bg-primary/10 mx-auto"></div>
        </div>
        
        {/* Animated dots */}
        <div className="flex justify-center space-x-2 mb-4">
          <div className="w-2 h-2 bg-primary rounded-full animate-bounce"></div>
          <div className="w-2 h-2 bg-primary rounded-full animate-bounce" style={{ animationDelay: '0.1s' }}></div>
          <div className="w-2 h-2 bg-primary rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
        </div>
        
        {/* Message with typing animation */}
        <p className="text-muted-foreground text-lg font-medium animate-pulse">
          {message}
        </p>
        
        {/* Progress bar */}
        <div className="w-64 h-1 bg-muted rounded-full mt-4 mx-auto overflow-hidden">
          <div className="h-full bg-gradient-to-r from-primary/60 to-primary rounded-full animate-[slide_2s_ease-in-out_infinite]"></div>
        </div>
      </div>
    </div>
  )
}

export default LoadingSpinner