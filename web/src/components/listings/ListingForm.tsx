"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { LISTING_STATUSES, listingStatusLabel, type ListingStatus } from "@/types/listing"

const baseSchema = z.object({
  title: z.string().min(3, "Title must be at least 3 characters").max(120, "Title is too long"),
  description: z.string().min(20, "Description must be at least 20 characters"),
  budget: z.coerce.number().positive("Budget must be greater than 0"),
  category: z.string().max(60, "Category is too long").optional(),
})

const editSchema = baseSchema.extend({
  status: z.enum(LISTING_STATUSES),
})

export interface ListingFormValues {
  title: string
  description: string
  budget: number
  category?: string
  status?: ListingStatus
}

interface ListingFormProps {
  mode: "create" | "edit"
  initialValues?: ListingFormValues
  submitting: boolean
  submitLabel: string
  onSubmit: (values: ListingFormValues) => void | Promise<void>
}

export function ListingForm({ mode, initialValues, submitting, submitLabel, onSubmit }: ListingFormProps): React.JSX.Element {
  const schema = mode === "edit" ? editSchema : baseSchema
  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<ListingFormValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues ?? { title: "", description: "", budget: 0, category: "", status: "open" },
  })

  const status = watch("status")

  return (
    <form
      onSubmit={handleSubmit((values) => onSubmit(values))}
      className="space-y-4"
      noValidate
    >
      <div className="space-y-1.5">
        <Label htmlFor="title">Title</Label>
        <Input id="title" placeholder="e.g. Build a marketing landing page" {...register("title")} />
        {errors.title && <p className="text-xs text-destructive">{errors.title.message}</p>}
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="description">Description</Label>
        <Textarea
          id="description"
          rows={6}
          placeholder="Describe the scope, deliverables, and timeline…"
          {...register("description")}
        />
        {errors.description && <p className="text-xs text-destructive">{errors.description.message}</p>}
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="budget">Budget (USD)</Label>
          <Input id="budget" type="number" min={1} step={1} {...register("budget")} />
          {errors.budget && <p className="text-xs text-destructive">{errors.budget.message}</p>}
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="category">Category (optional)</Label>
          <Input id="category" placeholder="e.g. Web Development" {...register("category")} />
          {errors.category && <p className="text-xs text-destructive">{errors.category.message}</p>}
        </div>
      </div>

      {mode === "edit" && (
        <div className="space-y-1.5">
          <Label htmlFor="status">Status</Label>
          <Select value={status} onValueChange={(v) => setValue("status", v as ListingStatus)}>
            <SelectTrigger id="status">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {LISTING_STATUSES.map((s) => (
                <SelectItem key={s} value={s}>
                  {listingStatusLabel(s)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}

      <Button type="submit" disabled={submitting}>
        {submitting ? "Saving…" : submitLabel}
      </Button>
    </form>
  )
}
