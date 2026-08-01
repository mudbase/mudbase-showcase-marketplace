import type { Metadata } from "next"
import Link from "next/link"
import { RegisterForm } from "@/components/auth/RegisterForm"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"

export const metadata: Metadata = { title: "Create account" }

export default function RegisterPage(): React.JSX.Element {
  return (
    <div className="container flex max-w-md flex-col justify-center py-16">
      <Card>
        <CardHeader>
          <CardTitle>Create your account</CardTitle>
          <CardDescription>Choose whether you&apos;re hiring or looking for work.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <RegisterForm />
          <p className="text-center text-sm text-muted-foreground">
            Already have an account?{" "}
            <Link href="/login" className="font-medium text-foreground underline underline-offset-4">
              Sign in
            </Link>
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
