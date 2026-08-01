import { Controller, useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Pressable, Text, View } from "react-native";
import { Check } from "lucide-react-native";
import { z } from "zod";
import { useAuth } from "@/hooks/useAuth";
import { TextField } from "@/components/ui/TextField";
import { Button } from "@/components/ui/Button";
import { ErrorNotice } from "@/components/ui/ErrorNotice";
import { cn } from "@/lib/cn";
import { appRoleSchema } from "@/api/schemas";

const schema = z.object({
  firstName: z.string().min(1, "First name is required"),
  lastName: z.string().min(1, "Last name is required"),
  email: z.string().min(1, "Email is required").email("Enter a valid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
  role: appRoleSchema,
  agreedToTerms: z.boolean().refine((v) => v === true, {
    message: "You must agree to the Terms of Service and Privacy Policy.",
  }),
});

type RegisterFormValues = z.infer<typeof schema>;

export function RegisterForm({ onSuccess }: { onSuccess: (role: "client" | "freelancer") => void }): React.JSX.Element {
  const { register, isSubmitting, error, clearError } = useAuth();
  const {
    control,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<RegisterFormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      firstName: "",
      lastName: "",
      email: "",
      password: "",
      role: "client",
      agreedToTerms: false,
    },
  });

  const role = watch("role");
  const agreedToTerms = watch("agreedToTerms");

  const onSubmit = async (values: RegisterFormValues): Promise<void> => {
    clearError();
    const ok = await register(values);
    if (ok) onSuccess(values.role);
  };

  return (
    <View className="gap-4">
      {error && <ErrorNotice message={error} />}

      <View className="gap-1.5">
        <Text className="text-sm font-medium text-foreground">I want to…</Text>
        <View className="flex-row gap-3">
          <Pressable
            accessibilityRole="radio"
            accessibilityState={{ checked: role === "client" }}
            onPress={() => setValue("role", "client")}
            className={cn(
              "flex-1 rounded-md border border-border p-3",
              role === "client" && "border-primary bg-secondary",
            )}
          >
            <Text className="text-center text-sm text-foreground">Hire freelancers</Text>
          </Pressable>
          <Pressable
            accessibilityRole="radio"
            accessibilityState={{ checked: role === "freelancer" }}
            onPress={() => setValue("role", "freelancer")}
            className={cn(
              "flex-1 rounded-md border border-border p-3",
              role === "freelancer" && "border-primary bg-secondary",
            )}
          >
            <Text className="text-center text-sm text-foreground">Find work</Text>
          </Pressable>
        </View>
      </View>

      <View className="flex-row gap-3">
        <Controller
          control={control}
          name="firstName"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField
              label="First name"
              value={value}
              onChangeText={onChange}
              onBlur={onBlur}
              autoComplete="given-name"
              containerClassName="flex-1"
              error={errors.firstName?.message}
            />
          )}
        />
        <Controller
          control={control}
          name="lastName"
          render={({ field: { onChange, onBlur, value } }) => (
            <TextField
              label="Last name"
              value={value}
              onChangeText={onChange}
              onBlur={onBlur}
              autoComplete="family-name"
              containerClassName="flex-1"
              error={errors.lastName?.message}
            />
          )}
        />
      </View>

      <Controller
        control={control}
        name="email"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Email"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            keyboardType="email-address"
            autoCapitalize="none"
            autoComplete="email"
            error={errors.email?.message}
          />
        )}
      />
      <Controller
        control={control}
        name="password"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label="Password"
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            secureTextEntry
            autoComplete="new-password"
            error={errors.password?.message}
          />
        )}
      />

      <View className="gap-1">
        <Pressable
          accessibilityRole="checkbox"
          accessibilityState={{ checked: agreedToTerms }}
          onPress={() => setValue("agreedToTerms", !agreedToTerms)}
          className="flex-row items-start gap-2"
        >
          <View
            className={cn(
              "mt-0.5 h-5 w-5 items-center justify-center rounded border border-border",
              agreedToTerms && "border-primary bg-primary",
            )}
          >
            {agreedToTerms && <Check size={14} color="#fbfaf9" />}
          </View>
          <Text className="flex-1 text-sm text-foreground">I agree to the Terms of Service and Privacy Policy.</Text>
        </Pressable>
        {errors.agreedToTerms && <Text className="text-xs text-destructive">{errors.agreedToTerms.message}</Text>}
      </View>

      <Button onPress={handleSubmit(onSubmit)} isLoading={isSubmitting}>
        {isSubmitting ? "Creating account…" : "Create account"}
      </Button>
    </View>
  );
}
