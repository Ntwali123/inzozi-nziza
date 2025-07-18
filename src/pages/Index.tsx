import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/ui/theme-toggle";
import { Sparkles } from "lucide-react";
import { Link } from "react-router-dom";

const Index = () => {
  return (
    <div className="min-h-screen relative overflow-hidden">
      {/* Theme toggle */}
      <div className="absolute top-4 right-4 z-20">
        <ThemeToggle />
      </div>

      {/* Gradient background */}
      <div className="absolute inset-0 bg-gradient-to-br from-primary/5 via-accent/5 to-secondary/10 dark:from-primary/10 dark:via-accent/10 dark:to-secondary/20" />
      
      {/* Content */}
      <div className="relative z-10 min-h-screen flex items-center justify-center">
        <div className="text-center max-w-4xl mx-auto px-4">
          <div className="animate-float mb-8">
            <Sparkles className="h-16 w-16 text-primary mx-auto mb-6 animate-glow" />
          </div>
          
          <h1 className="text-6xl md:text-7xl font-bold mb-6 text-primary animate-fade-in bg-gradient-to-r from-primary via-primary/80 to-primary bg-clip-text text-transparent">
            Inzozi Nziza
          </h1>
          
          <p className="text-2xl md:text-3xl text-muted-foreground mb-8 animate-fade-in font-light">
            Community Savings & Loans Platform
          </p>
          
          <p className="text-lg text-muted-foreground mb-4 animate-fade-in max-w-2xl mx-auto">
            Building Dreams Together
          </p>
          
          <p className="text-muted-foreground mb-12 animate-fade-in max-w-3xl mx-auto leading-relaxed">
            Join our community to contribute, save, and access loans to achieve your financial goals.
            Every member contributes 105,000 RWF to be part of our growing financial community.
          </p>
          
          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center animate-fade-in">
            <Button asChild size="lg" className="text-lg px-8 py-6 animate-glow">
              <Link to="/auth">
                Get Started
              </Link>
            </Button>
            <Button asChild variant="outline" size="lg" className="text-lg px-8 py-6">
              <Link to="/auth">
                Sign In
              </Link>
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Index;
