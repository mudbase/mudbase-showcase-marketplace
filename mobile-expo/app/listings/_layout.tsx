import { Stack } from "expo-router";

/** Every screen under /listings gets a real native header (title + back button) - unlike the
 * tab screens, these are pushed detail/form screens, not the app's persistent bottom-tab
 * surfaces, so a standard stack header is the right fit here. Each screen sets its own `title`
 * via a `<Stack.Screen options={{ title }} />` at the top of its own component. */
export default function ListingsLayout(): React.JSX.Element {
  return <Stack screenOptions={{ headerShown: true, headerBackTitle: "Back" }} />;
}
