import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { View } from "react-native";
import { z } from "zod";
import { Button } from "@/components/ui/Button";
import { TextField } from "@/components/ui/TextField";
import { SelectField } from "@/components/ui/SelectField";
import { LISTING_STATUSES, listingStatusLabel, type ListingStatus } from "@/api/schemas";

// A single static schema (rather than branching between a "create" and "edit" variant, the way
// the web reference's ListingForm does) keeps `useForm`'s generic inference simple under strict
// TypeScript: a runtime ternary between two structurally-different ZodObjects otherwise confuses
// the resolver's generic to the point of dropping the `status` key entirely. `budget` is plain
// `z.number()` rather than `z.coerce.number()` for the same reason — RHF's `Controller` already
// hands this component a numeric string from the `TextField`'s `onChangeText`, converted to a
// real `number` before it reaches `onChange` (see below), so there is nothing left to coerce.
// `status` is optional here since it is never registered/validated as a rendered input in
// "create" mode — it only round-trips through `defaultValues`/`setValue`, always with a valid
// value already in hand.
const schema = z.object({
  title: z.string().min(3, "Title must be at least 3 characters").max(120, "Title is too long"),
  description: z.string().min(20, "Description must be at least 20 characters"),
  budget: z.number().positive("Budget must be greater than 0"),
  category: z.string().max(60, "Category is too long").optional(),
  status: z.enum(LISTING_STATUSES).optional(),
});

export interface ListingFormValues {
  title: string;
  description: string;
  budget: number;
  category?: string;
  status?: ListingStatus;
}

interface ListingFormProps {
  mode: "create" | "edit";
  initialValues?: ListingFormValues;
  submitting: boolean;
  submitLabel: string;
  onSubmit: (values: ListingFormValues) => void | Promise<void>;
}

const STATUS_OPTIONS = LISTING_STATUSES.map((s) => ({ value: s, label: listingStatusLabel(s) }));

export function ListingForm({
  mode,
  initialValues,
  submitting,
  submitLabel,
  onSubmit,
}: ListingFormProps): React.JSX.Element {
  const {
    control,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<ListingFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues ?? { title: "", description: "", budget: 0, category: "", status: "open" },
  });

  const status = watch("status") ?? "open";

  return (
    <View className="gap-4">
      <Controller
        control={control}
        name="title"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Title"
            placeholder="e.g. Build a marketing landing page"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            error={errors.title?.message}
          />
        )}
      />

      <Controller
        control={control}
        name="description"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Description"
            placeholder="Describe the scope, deliverables, and timeline…"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            multiline
            numberOfLines={6}
            error={errors.description?.message}
          />
        )}
      />

      <View className="flex-row gap-3">
        <Controller
          control={control}
          name="budget"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField
              label="Budget (USD)"
              keyboardType="numeric"
              value={value ? String(value) : ""}
              onChangeText={(text) => onChange(Number(text.replace(/[^0-9]/g, "")) || 0)}
              onBlur={onBlur}
              containerClassName="flex-1"
              error={errors.budget?.message}
            />
          )}
        />
        <Controller
          control={control}
          name="category"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField
              label="Category (optional)"
              placeholder="e.g. Web Development"
              value={value ?? ""}
              onChangeText={onChange}
              onBlur={onBlur}
              containerClassName="flex-1"
              error={errors.category?.message}
            />
          )}
        />
      </View>

      {mode === "edit" && (
        <SelectField
          label="Status"
          value={status}
          onChange={(v) => setValue("status", v)}
          options={STATUS_OPTIONS}
        />
      )}

      <Button onPress={handleSubmit((values) => onSubmit(values))} isLoading={submitting}>
        {submitting ? "Saving…" : submitLabel}
      </Button>
    </View>
  );
}
