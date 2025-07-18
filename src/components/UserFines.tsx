import { useState, useEffect } from "react";
import { Badge } from "@/components/ui/badge";
import { AlertCircle } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";

interface Fine {
  id: string;
  user_id: string;
  amount: number;
  reason: string;
  status: "pending" | "paid" | "cancelled";
  issued_at: string;
  paid_at: string | null;
  admin_notes: string | null;
  created_at: string;
  fine_payments: {
    amount: number;
  }[];
}

interface UserFinesProps {
  userId: string;
}

function UserFines({ userId }: UserFinesProps) {
  const [fines, setFines] = useState<Fine[]>([]);
  const [loading, setLoading] = useState(true);
  const { toast } = useToast();

  useEffect(() => {
    loadFines();
  }, [userId]);

  const loadFines = async () => {
    try {
      const { data, error } = await supabase
        .from("fines")
        .select(
          `
          *,
          fine_payments (
            amount
          )
        `
        )
        .eq("user_id", userId)
        .order("issued_at", { ascending: false });

      if (error) throw error;
      setFines(data || []);
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error
          ? error.message
          : "An error occurred while loading fines";
      toast({
        title: "Error loading fines",
        description: errorMessage,
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const getStatusVariant = (
    status: string
  ): "default" | "secondary" | "destructive" | "outline" => {
    switch (status) {
      case "paid":
        return "default";
      case "pending":
        return "secondary";
      case "cancelled":
        return "destructive";
      default:
        return "outline";
    }
  };

  const getRemainingAmount = (fine: Fine) => {
    const totalPaid =
      fine.fine_payments?.reduce((sum, payment) => sum + payment.amount, 0) ||
      0;
    return fine.amount - totalPaid;
  };

  const totalPendingAmount = fines
    .filter((fine) => fine.status === "pending")
    .reduce((sum, fine) => sum + getRemainingAmount(fine), 0);

  if (loading) {
    return <div>Loading fines...</div>;
  }

  if (fines.length === 0) {
    return null;
  }

  return (
    <div>
      {totalPendingAmount > 0 && (
        <div className="mb-4 p-4 bg-destructive/10 rounded-lg">
          <p className="text-sm font-medium text-destructive">
            You have pending fines totaling{" "}
            {totalPendingAmount.toLocaleString()} RWF
          </p>
        </div>
      )}
      <div className="space-y-4">
        {fines.map((fine) => {
          const remainingAmount = getRemainingAmount(fine);
          return (
            <div
              key={fine.id}
              className="flex items-center justify-between border-b pb-2 last:border-0"
            >
              <div>
                <p className="font-medium">
                  {remainingAmount.toLocaleString()} RWF
                </p>
                <p className="text-sm text-muted-foreground">{fine.reason}</p>
                <p className="text-xs text-muted-foreground">
                  Issued: {new Date(fine.issued_at).toLocaleDateString()}
                </p>
              </div>
              <Badge variant={getStatusVariant(fine.status)}>
                {fine.status}
              </Badge>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export default UserFines;
