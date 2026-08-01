import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { View } from "react-native";
import { z } from "zod";
import { Button } from "@/components/ui/Button";
import { TextField } from "@/components/ui/TextField";

// Plain z.number() rather than z.coerce.number() - see ListingForm.tsx's comment on the same
// choice. The Controller below already converts the TextField's string input to a real number
// before calling onChange.
const schema = z.object({
  coverLetter: z.string().min(20, "Cover letter must be at least 20 characters"),
  proposedRate: z.number().positive("Proposed rate must be greater than 0"),
});

export type ProposalFormValues = z.infer<typeof schema>;

interface ProposalFormProps {
  submitting: boolean;
  onSubmit: (values: ProposalFormValues) => void | Promise<void>;
}

export function ProposalForm({ submitting, onSubmit }: ProposalFormProps): React.JSX.Element {
  const {
    control,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<ProposalFormValues>({ resolver: zodResolver(schema), defaultValues: { coverLetter: "", proposedRate: 0 } });

  const submit = async (values: ProposalFormValues): Promise<void> => {
    await onSubmit(values);
    reset();
  };

  return (
    <View className="gap-4">
      <Controller
        control={control}
        name="coverLetter"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Cover letter"
            placeholder="Explain why you're a good fit for this job…"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            multiline
            numberOfLines={5}
            error={errors.coverLetter?.message}
          />
        )}
      />
      <Controller
        control={control}
        name="proposedRate"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Proposed rate (USD)"
            keyboardType="numeric"
            value={value ? String(value) : ""}
            onChangeText={(text) => onChange(Number(text.replace(/[^0-9]/g, "")) || 0)}
            onBlur={onBlur}
            error={errors.proposedRate?.message}
          />
        )}
      />
      <Button onPress={handleSubmit(submit)} isLoading={submitting}>
        {submitting ? "Submitting…" : "Submit proposal"}
      </Button>
    </View>
  );
}
