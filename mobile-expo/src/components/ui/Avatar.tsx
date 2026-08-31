import { Text, View } from "react-native";
import { initials } from "@/lib/format";
import { cn } from "@/lib/cn";

const SIZES = { sm: 24, md: 32, lg: 40 } as const;

export interface AvatarProps {
  name: string;
  size?: keyof typeof SIZES;
  className?: string;
}

/** Initials-only avatar - there is no `users` collection and no profile photo anywhere in this
 * app's data model (see plan/build-plan.md), so a name is all there ever is to render. */
export function Avatar({ name, size = "md", className }: AvatarProps): React.JSX.Element {
  const dimension = SIZES[size];
  return (
    <View
      accessibilityElementsHidden
      importantForAccessibility="no"
      className={cn("items-center justify-center rounded-full bg-primary", className)}
      style={{ width: dimension, height: dimension }}
    >
      <Text className="font-semibold text-primary-foreground" style={{ fontSize: dimension * 0.4 }}>
        {initials(name)}
      </Text>
    </View>
  );
}
