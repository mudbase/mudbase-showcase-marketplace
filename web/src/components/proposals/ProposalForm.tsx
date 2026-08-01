"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"

const schema = z.object({
  coverLetter: z.string().min(20, "Cover letter must be at least 20 characters"),
  proposedRate: z.coerce.number().positive("Proposed rate must be greater than 0"),
})

export type ProposalFormValues = z.infer<typeof schema>

interface ProposalFormProps {
  submitting: boolean
  onSubmit: (values: ProposalFormValues) => void | Promise<void>
}

export function ProposalForm({ submitting, onSubmit }: ProposalFormProps): React.JSX.Element {
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<ProposalFormValues>({ resolver: zodResolver(schema), defaultValues: { coverLetter: "", proposedRate: 0 } })

  const submit = async (values: ProposalFormValues): Promise<void> => {
    await onSubmit(values)
    reset()
  }

  return (
    <form onSubmit={handleSubmit(submit)} className="space-y-4" noValidate>
      <div className="space-y-1.5">
        <Label htmlFor="coverLetter">Cover letter</Label>
        <Textarea
          id="coverLetter"
          rows={5}
          placeholder="Explain why you're a good fit for this job…"
          {...register("coverLetter")}
        />
        {errors.coverLetter && <p className="text-xs text-destructive">{errors.coverLetter.message}</p>}
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="proposedRate">Proposed rate (USD)</Label>
        <Input id="proposedRate" type="number" min={1} step={1} {...register("proposedRate")} />
        {errors.proposedRate && <p className="text-xs text-destructive">{errors.proposedRate.message}</p>}
      </div>
      <Button type="submit" disabled={submitting}>
        {submitting ? "Submitting…" : "Submit proposal"}
      </Button>
    </form>
  )
}
