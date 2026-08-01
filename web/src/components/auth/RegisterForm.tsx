"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useAuth } from "@/hooks/useAuth"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

const schema = z.object({
  firstName: z.string().min(1, "First name is required"),
  lastName: z.string().min(1, "Last name is required"),
  email: z.string().email("Enter a valid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
  role: z.enum(["client", "freelancer"]),
  agreedToTerms: z.boolean().refine((v) => v === true, {
    message: "You must agree to the Terms of Service and Privacy Policy.",
  }),
})

type FormValues = z.infer<typeof schema>

export function RegisterForm(): React.JSX.Element {
  const { register: registerUser, loading, error } = useAuth()
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { role: "client", agreedToTerms: false } })

  const onSubmit = async (values: FormValues): Promise<void> => {
    await registerUser(values.email, values.password, values.firstName, values.lastName, values.role, values.agreedToTerms)
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}

      <div className="space-y-1.5">
        <Label>I want to…</Label>
        <div className="grid grid-cols-2 gap-3">
          <label className="flex cursor-pointer items-center gap-2 rounded-md border border-input p-3 text-sm has-[:checked]:border-primary has-[:checked]:bg-secondary">
            <input type="radio" value="client" className="h-4 w-4" {...register("role")} />
            Hire freelancers
          </label>
          <label className="flex cursor-pointer items-center gap-2 rounded-md border border-input p-3 text-sm has-[:checked]:border-primary has-[:checked]:bg-secondary">
            <input type="radio" value="freelancer" className="h-4 w-4" {...register("role")} />
            Find work
          </label>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <Label htmlFor="firstName">First name</Label>
          <Input id="firstName" autoComplete="given-name" {...register("firstName")} />
          {errors.firstName && <p className="text-xs text-destructive">{errors.firstName.message}</p>}
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="lastName">Last name</Label>
          <Input id="lastName" autoComplete="family-name" {...register("lastName")} />
          {errors.lastName && <p className="text-xs text-destructive">{errors.lastName.message}</p>}
        </div>
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="email">Email</Label>
        <Input id="email" type="email" autoComplete="email" {...register("email")} />
        {errors.email && <p className="text-xs text-destructive">{errors.email.message}</p>}
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="password">Password</Label>
        <Input id="password" type="password" autoComplete="new-password" {...register("password")} />
        {errors.password && <p className="text-xs text-destructive">{errors.password.message}</p>}
      </div>
      <div className="space-y-1">
        <label className="flex items-start gap-2 text-sm">
          <input type="checkbox" className="mt-0.5 h-4 w-4 rounded border-input" {...register("agreedToTerms")} />
          <span>I agree to the Terms of Service and Privacy Policy.</span>
        </label>
        {errors.agreedToTerms && <p className="text-xs text-destructive">{errors.agreedToTerms.message}</p>}
      </div>
      <Button type="submit" className="w-full" disabled={loading}>
        {loading ? "Creating account…" : "Create account"}
      </Button>
    </form>
  )
}
